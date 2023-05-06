"=============================================================================
" FILE: git.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
"          Robert Nelson     <robert@rnelson.ca>
" License: MIT license
"=============================================================================

" Global options definition.
call dein#util#_set_default(
      \ 'g:dein#types#git#clone_depth', 0)
call dein#util#_set_default(
      \ 'g:dein#types#git#command_path', 'git')
call dein#util#_set_default(
      \ 'g:dein#types#git#default_hub_site', 'github.com')
call dein#util#_set_default(
      \ 'g:dein#types#git#default_protocol', 'https')
call dein#util#_set_default(
      \ 'g:dein#types#git#pull_command', 'pull --ff --ff-only')
call dein#util#_set_default(
      \ 'g:dein#types#git#enable_partial_clone', v:false)


function! dein#types#git#define() abort
  return s:type
endfunction

let s:type = #{
      \   name: 'git',
      \   command: g:dein#types#git#command_path,
      \   executable: executable(g:dein#types#git#command_path),
      \ }

function! s:type.init(repo, options) abort
  if !self.executable
    return {}
  endif

  if a:repo =~# '^/\|^\a:[/\\]' && s:is_git_dir(a:repo.'/.git')
    " Local repository.
    return #{ type: 'git', local: 1 }
  elseif a:repo =~#
        \ '//\%(raw\|gist\)\.githubusercontent\.com/\|/archive/[^/]\+\.zip$'
    return {}
  endif

  const uri = self.get_uri(a:repo, a:options)
  if uri ==# ''
    return {}
  endif

  const directory = uri->substitute('\.git$', '', '')
        \ ->substitute('^https:/\+\|^git@', '', '')
        \ ->substitute(':', '/', 'g')

  return #{
        \  type: 'git',
        \  path: dein#util#_get_base_path().'/repos/'.directory,
        \ }
endfunction
function! s:type.get_uri(repo, options) abort
  if a:repo =~# '^/\|^\a:[/\\]'
    return s:is_git_dir(a:repo.'/.git') ? a:repo : ''
  endif

  if a:repo =~# '^git@'
    " Parse "git@host:name" pattern
    let protocol = 'ssh'
    let host = a:repo[4:]->matchstr('[^:]*')
    let name = a:repo[4 + len(host) + 1 :]
  else
    let protocol = a:repo->matchstr('^.\{-}\ze://')
    let rest = a:repo[protocol->len():]
    let name = rest->substitute('^://[^/]*/', '', '')
    let host = rest->matchstr('^://\zs[^/]*\ze/')->substitute(':.*$', '', '')
  endif
  if host ==# ''
    let host = g:dein#types#git#default_hub_site
  endif

  if protocol ==# ''
        \ || a:repo =~# '\<\%(gh\|github\|bb\|bitbucket\):\S\+'
        \ || a:options->has_key('type__protocol')
    let protocol = a:options->get('type__protocol',
          \ g:dein#types#git#default_protocol)
  endif

  if protocol !=# 'https' && protocol !=# 'ssh'
    call dein#util#_error(
          \ printf('Repo: %s The protocol "%s" is unsecure and invalid.',
          \ a:repo, protocol))
    return ''
  endif

  if a:repo !~# '/'
    call dein#util#_error(
          \ printf('vim-scripts.org is deprecated.'
          \ .. ' You can use "vim-scripts/%s" instead.', a:repo))
    return ''
  else
    let uri = (protocol ==# 'ssh' &&
          \    (host ==# 'github.com' || host ==# 'bitbucket.com'
          \     || host ==# 'bitbucket.org')) ?
          \ 'git@' .. host .. ':' .. name :
          \ protocol .. '://' .. host .. '/' .. name
  endif

  return uri
endfunction

function! s:type.get_sync_command(plugin) abort
  if !(a:plugin.path->isdirectory())
    let commands = []

    call add(commands, self.command)
    call add(commands, '-c')
    call add(commands, 'credential.helper=')
    call add(commands, 'clone')
    call add(commands, '--recursive')

    const depth = a:plugin->get('type__depth', g:dein#types#git#clone_depth)
    if depth > 0 && self.get_uri(a:plugin.repo, a:plugin) !~# '^git@'
      call add(commands, '--depth=' .. depth)

      if a:plugin->get('rev', '') !=# ''
        call add(commands, '--branch')
        call add(commands, a:plugin.rev)
      endif
    endif

    if g:dein#types#git#enable_partial_clone
      call add(commands, '--filter=blob:none')
    endif

    call add(commands, self.get_uri(a:plugin.repo, a:plugin))
    call add(commands, a:plugin.path)

    return commands
  else
    const git = self.command

    const fetch_cmd = git .. ' -c credential.helper= fetch '
    const remote_origin_cmd = git .. ' remote set-head origin -a'
    const pull_cmd = git .. ' ' .. g:dein#types#git#pull_command
    const submodule_cmd = git .. ' submodule update --init --recursive'

    " Note: "remote_origin_cmd" does not work when "depth" is specified.
    const depth = a:plugin->get('type__depth', g:dein#types#git#clone_depth)

    if dein#util#_is_powershell()
      let cmd = fetch_cmd
      if depth <= 0
        let cmd ..= '; if ($?) { ' .. remote_origin_cmd .. ' }'
      endif
      let cmd ..= '; if ($?) { ' .. pull_cmd .. ' }'
      let cmd ..= '; if ($?) { ' .. submodule_cmd .. ' }'
    else
      const and = dein#util#_is_fish() ? '; and ' : ' && '
      let cmds = [fetch_cmd]
      if depth <= 0
        call add(cmds, remote_origin_cmd)
      endif
      let cmds += [pull_cmd, submodule_cmd]
      let cmd = join(cmds, and)
    endif

    return cmd
  endif
endfunction

function! s:type.get_revision_number(plugin) abort
  return s:git_get_revision(a:plugin.path)
endfunction
function! s:type.get_log_command(plugin, new_rev, old_rev) abort
  if !self.executable || a:new_rev ==# '' || a:old_rev ==# ''
    return []
  endif

  " NOTE: If the a:old_rev is not the ancestor of two branches. Then do not use
  " %s^.  use %s^ will show one commit message which already shown last time.
  const is_not_ancestor = dein#install#_system(
        \ self.command .. ' merge-base '
        \ .. a:old_rev .. ' ' .. a:new_rev) ==# a:old_rev
  return printf(self.command
        \ .. ' log %s%s..%s --graph --no-show-signature'
        \ .. ' --pretty=format:"%%h [%%cr] %%s"',
        \ a:old_rev, (is_not_ancestor ? '' : '^'), a:new_rev)
endfunction
function! s:type.get_revision_lock_command(plugin) abort
  if !self.executable
    return []
  endif

  let rev = a:plugin->get('rev', '')
  if rev =~# '*'
    " Use the released tag (git 1.9.2 or above required)
    const output = dein#install#_system(
          \ [self.command, 'tag', rev,
          \  '--list', '--sort', '-version:refname'])
    let rev = output->split('\n')->get(0, '')
  endif
  if rev ==# ''
    " Fix detach HEAD.
    " Use symbolic-ref feature (git 1.8.7 or above required)
    const output = dein#install#_system(
          \ [self.command, 'symbolic-ref', '--short', 'HEAD'])
    let rev = output->split('\n')->get(0, '')
    if rev =~# 'fatal: '
      " Fix "fatal: ref HEAD is not a symbolic ref" error
      " NOTE: Should specify the default branch?
      let rev = 'main'
    endif
  endif

  return [self.command, 'checkout', rev, '--']
endfunction
function! s:type.get_rollback_command(plugin, rev) abort
  if !self.executable
    return []
  endif

  return [self.command, 'reset', '--hard', a:rev]
endfunction
function! s:type.get_diff_command(plugin, old_rev, new_rev) abort
  if !self.executable
    return []
  endif

  return [self.command, 'diff', a:old_rev .. '..' .. a:new_rev,
        \ '--', 'doc', 'README', 'README.md']
endfunction

function! s:is_git_dir(path) abort
  if a:path->isdirectory()
    const git_dir = a:path
  elseif a:path->filereadable()
    " check if this is a gitdir file
    " File starts with "gitdir: " and all text after this string is treated
    " as the path. Any CR or NLs are stripped off the end of the file.
    const buf = a:path->readfile('b')->join("\n")
    const matches = buf->matchlist('\C^gitdir: \(\_.*[^\r\n]\)[\r\n]*$')
    if matches->empty()
      return 0
    endif
    let path = a:path->fnamemodify(':h')
    if a:path->fnamemodify(':t') ==# ''
      " if there's no tail, the path probably ends in a directory separator
      let path = path->fnamemodify(':h')
    endif
    const git_dir = s:join_paths(path, matches[1])
    if !(git_dir->isdirectory())
      return 0
    endif
  else
    return 0
  endif

  " Git only considers it to be a git dir if a few required files/dirs exist
  " and are accessible inside the directory.
  " NOTE: We can't actually test file permissions the way we'd like to, since
  " getfperm() gives the mode string but doesn't tell us whether the user or
  " group flags apply to us. Instead, just check if dirname/. is a directory.
  " This should also check if we have search permissions.
  " I'm assuming here that dirname/. works on windows, since I can't test.
  " NOTE: Git also accepts having the GIT_OBJECT_DIRECTORY env var set instead
  " of using .git/objects, but we don't care about that.
  for name in ['objects', 'refs']
    if !(s:join_paths(git_dir, name)->isdirectory())
      return 0
    endif
  endfor

  " Git also checks if HEAD is a symlink or a properly-formatted file.
  " We don't really care to actually validate this, so let's just make
  " sure the file exists and is readable.
  " NOTE: It may also be a symlink, which can point to a path that doesn't
  " necessarily exist yet.
  const head = s:join_paths(git_dir, 'HEAD')
  if !(head->filereadable()) && head->getftype() !=# 'link'
    return 0
  endif

  " Sure looks like a git directory. There's a few subtleties where we'll
  " accept a directory that git itself won't, but I think we can safely ignore
  " those edge cases.
  return 1
endfunction

let s:is_windows = dein#util#_is_windows()

function! s:join_paths(path1, path2) abort
  " Joins two paths together, handling the case where the second path
  " is an absolute path.
  if s:is_absolute(a:path2)
    return a:path2
  endif
  if a:path1 =~ (s:is_windows ? '[\\/]$' : '/$')
        \ || a:path2 =~ (s:is_windows ? '^[\\/]' : '^/')
    " the appropriate separator already exists
    return a:path1 .. a:path2
  else
    " NOTE: I'm assuming here that '/' is always valid as a directory
    " separator on Windows. I know Windows has paths that start with \\?\ that
    " disable behavior like that, but I don't know how Vim deals with that.
    return a:path1 .. '/' .. a:path2
  endif
endfunction

if s:is_windows
  function! s:is_absolute(path) abort
    return a:path =~# '^[\\/]\|^\a:'
  endfunction
else
  function! s:is_absolute(path) abort
    return a:path =~# '^/'
  endfunction
endif

" From minpac plugin manager
" https://github.com/k-takata/minpac
" https://github.com/junegunn/vim-plug/pull/937
function! s:isabsolute(dir) abort
  return a:dir =~# '^/' || (has('win32') && a:dir =~? '^\%(\\\|[A-Z]:\)')
endfunction

function! s:get_gitdir(dir) abort
  let gitdir = a:dir .. '/.git'
  if gitdir->isdirectory()
    return gitdir
  endif
  try
    const line = gitdir->readfile()[0]
    if line =~# '^gitdir: '
      let gitdir = line[8:]
      if !s:isabsolute(gitdir)
        let gitdir = a:dir .. '/' .. gitdir
      endif
      if gitdir->isdirectory()
        return gitdir
      endif
    endif
  catch
  endtry
  return ''
endfunction

function! s:git_get_remote_origin_url(dir) abort
  let gitdir = s:get_gitdir(a:dir)
  if gitdir ==# ''
    return ''
  endif
  try
    let lines = (gitdir .. '/config')->readfile()
    let [n, ll, url] = [0, lines->len(), '']
    while n < ll
      let line = lines[n]->trim()
      if line->stridx('[remote "origin"]') != 0
        let n += 1
        continue
      endif
      let n += 1
      while n < ll
        let line = lines[n]->trim()
        if line ==# '['
          break
        endif
        let url = line->matchstr('^url\s*=\s*\zs[^ #]\+')
        if !(url->empty())
          break
        endif
        let n += 1
      endwhile
      let n += 1
    endwhile
    return url
  catch
    return ''
  endtry
endfunction

function! s:git_get_revision(dir) abort
  let gitdir = s:get_gitdir(a:dir)
  if gitdir ==# ''
    return ''
  endif
  try
    let line = (gitdir .. '/HEAD')->readfile()[0]
    if line =~# '^ref: '
      let ref = line[5:]
      if (gitdir .. '/' .. ref)->filereadable()
        return (gitdir .. '/' .. ref)->readfile()[0]
      endif
      for line in (gitdir .. '/packed-refs')->readfile()
        if line =~# ' ' .. ref
          return line->substitute('^\([0-9a-f]*\) ', '\1', '')
        endif
      endfor
    endif
    return line
  catch
  endtry
  return ''
endfunction

function! s:git_get_branch(dir) abort
  let gitdir = s:get_gitdir(a:dir)
  if gitdir ==# ''
    return ''
  endif
  try
    const line = (gitdir .. '/HEAD')->readfile()[0]
    if line =~# '^ref: refs/heads/'
      return line[16:]
    endif
    return 'HEAD'
  catch
    return ''
  endtry
endfunction
