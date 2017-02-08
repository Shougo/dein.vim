"=============================================================================
" FILE: install.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

" Variables
let s:global_context = {}
let s:job_info = {}
let s:log = []
let s:updates_log = []
let s:progress = ''

" Global options definition.
let g:dein#install_max_processes =
      \ get(g:, 'dein#install_max_processes', 8)
let g:dein#install_progress_type =
      \ get(g:, 'dein#install_progress_type', 'echo')
let g:dein#install_message_type =
      \ get(g:, 'dein#install_message_type', 'echo')
let g:dein#install_process_timeout =
      \ get(g:, 'dein#install_process_timeout', 120)
let g:dein#install_log_filename =
      \ get(g:, 'dein#install_log_filename', '')

function! dein#install#_update(plugins, update_type, async) abort
  if dein#util#_is_sudo()
    call s:error('update/install is disabled in sudo session.')
    return
  endif

  let plugins = dein#util#_get_plugins(a:plugins)

  if a:update_type ==# 'install'
    let plugins = filter(plugins, '!isdirectory(v:val.path)')
  elseif a:update_type ==# 'check_update'
    let plugins = filter(plugins, 'isdirectory(v:val.path)')
  endif

  if empty(plugins)
    call s:error('Target plugins are not found.')
    call s:error('You may have used the wrong plugin name,'.
          \ ' or all of the plugins are already installed.')
    return
  endif
  if a:async && !empty(s:global_context) &&
        \ confirm('The installation has not finished. Cancel now?',
        \         "yes\nNo", 2) != 1
    return
  endif

  " Set context.
  let context = s:init_context(plugins, a:update_type, a:async)

  call s:init_variables(context)
  call s:start()

  if !a:async || has('vim_starting')
    return s:update_loop(context)
  endif

  augroup dein-install
    autocmd!
  augroup END

  if exists('s:timer')
    call timer_stop(s:timer)
    unlet s:timer
  endif

  function! s:timer_handler(timer) abort
    call s:install_async(s:global_context)
  endfunction
  let s:timer = timer_start(1000,
        \ function('s:timer_handler'), {'repeat': -1})
endfunction
function! s:update_loop(context) abort
  let errored = 0
  try
    if has('vim_starting')
      while !empty(s:global_context)
        let errored = s:install_async(s:global_context)
        sleep 50ms
      endwhile
    else
      let errored = s:install_blocking(a:context)
    endif
  catch
    call s:error(v:exception)
    call s:error(v:throwpoint)
    return 1
  endtry

  return errored
endfunction

function! dein#install#_reinstall(plugins) abort
  let plugins = dein#util#_get_plugins(a:plugins)

  for plugin in plugins
    " Remove the plugin
    if plugin.type ==# 'none'
          \ || get(plugin, 'local', 0)
          \ || (plugin.sourced &&
          \     index(['dein', 'vimproc'], plugin.normalized_name) >= 0)
      call dein#util#_error(
            \ printf('|%s| Cannot reinstall the plugin!', plugin.name))
      continue
    endif

    " Reinstall.
    call s:print_progress_message(printf('|%s| Reinstalling...', plugin.name))

    if isdirectory(plugin.path)
      call dein#install#_rm(plugin.path)
    endif
  endfor

  call dein#install#_update(dein#util#_convert2list(a:plugins),
        \ 'install', 0)
endfunction
function! dein#install#_direct_install(repo, options) abort
  let options = copy(a:options)
  let options.merged = 0

  let plugin = dein#add(a:repo, options)
  if empty(plugin)
    return
  endif

  call dein#install#_update(plugin.name, 'install', 0)
  call dein#source(plugin.name)

  " Add to direct_install.vim
  let file = dein#get_direct_plugins_path()
  let line = printf('call dein#add(%s, %s)',
        \ string(a:repo), string(options))
  if !filereadable(file)
    call writefile([line], file)
  else
    call writefile(add(readfile(file), line), file)
  endif
endfunction
function! dein#install#_rollback(date, plugins) abort
  let plugins = dein#util#_get_plugins(a:plugins)

  let glob = s:get_rollback_directory() . '/' . a:date . '*'
  let rollbacks = reverse(sort(dein#util#_globlist(glob)))
  if empty(rollbacks)
    return
  endif

  let revisions = dein#_json2vim(readfile(rollbacks[0])[0])

  call filter(plugins, "has_key(revisions, v:val.name)
        \ && has_key(dein#util#_get_type(v:val.type),
        \            'get_rollback_command')
        \ && s:check_rollback(v:val)
        \ && s:get_revision_number(v:val) !=# revisions[v:val.name]")
  if empty(plugins)
    return
  endif

  for plugin in plugins
    let type = dein#util#_get_type(plugin.type)
    let cmd = type.get_rollback_command(
          \ dein#util#_get_type(plugin.type), revisions[plugin.name])
    call dein#install#_each(cmd, plugin)
  endfor

  call dein#recache_runtimepath()
  call s:error('Rollback to '.fnamemodify(rollbacks[0], ':t').' version.')
endfunction

function! dein#install#_recache_runtimepath() abort
  if dein#util#_is_sudo()
    call s:error('recache_runtimepath() is disabled in sudo session.')
    return
  endif

  " Clear runtime path.
  call s:clear_runtimepath()

  let plugins = values(dein#get())

  let merged_plugins = filter(copy(plugins), 'v:val.merged')

  call s:copy_files(filter(copy(merged_plugins), 'v:val.lazy'), '')
  " Remove plugin directory
  call dein#install#_rm(dein#util#_get_runtime_path() . '/plugin')
  call dein#install#_rm(dein#util#_get_runtime_path() . '/after/plugin')

  call s:copy_files(filter(copy(merged_plugins), '!v:val.lazy'), '')

  call s:helptags()

  call s:generate_ftplugin()

  " Clear ftdetect and after/ftdetect directories.
  call dein#install#_rm(
        \ dein#util#_get_runtime_path().'/ftdetect')
  call dein#install#_rm(
        \ dein#util#_get_runtime_path().'/after/ftdetect')

  call s:merge_files(plugins, 'ftdetect')
  call s:merge_files(plugins, 'after/ftdetect')

  if !has('vim_starting')
    if exists('g:did_load_filetypes')
      filetype off | filetype on
    endif
    silent! runtime! plugin/**/*.vim
  endif

  silent call dein#remote_plugins()

  call dein#call_hook('post_source')

  call dein#util#_save_merged_plugins(
        \ sort(map(values(g:dein#_plugins), 'v:val.repo')))

  call s:save_rollback()

  call dein#clear_state()

  call s:log([strftime('Runtimepath updated: (%Y/%m/%d %H:%M:%S)')])

  call dein#call_hook('done_update')
endfunction
function! s:clear_runtimepath() abort
  if dein#util#_get_cache_path() ==# ''
    call dein#util#_error('Invalid base path.')
    return
  endif

  let parent = printf('%s/temp/%d', dein#util#_get_cache_path(), getpid())
  let dest = parent . '/' . strftime('%Y%m%d%H%M%S')
  if !isdirectory(parent)
    call mkdir(parent, 'p')
  endif
  silent! let err = rename(dein#util#_get_runtime_path(), dest)
  if get(l:, 'err', -1)
    call dein#util#_error('Rename failed.')
    call dein#util#_error('src=' . dein#util#_get_runtime_path())
    call dein#util#_error('dest=' . dest)
    return
  endif

  " Create runtime path
  call mkdir(dein#util#_get_runtime_path(), 'p')

  " Remove previous runtime path
  for path in filter(dein#util#_globlist(
        \ dein#util#_get_cache_path().'/temp/*'),
        \   "fnamemodify(v:val, ':t') !=# getpid()")
    call dein#install#_rm(path)
  endfor
endfunction
function! s:helptags() abort
  if g:dein#_runtime_path ==# '' || dein#util#_is_sudo()
    return ''
  endif

  try
    let tags = dein#util#_get_runtime_path() . '/doc'
    if !isdirectory(tags)
      call mkdir(tags, 'p')
    endif
    call s:copy_files(filter(
          \ values(dein#get()), '!v:val.merged'), 'doc')
    silent execute 'helptags' fnameescape(tags)
  catch /^Vim(helptags):E151:/
    " Ignore an error that occurs when there is no help file
  catch
    call s:error('Error generating helptags:')
    call s:error(v:exception)
    call s:error(v:throwpoint)
  endtry
endfunction
function! s:copy_files(plugins, directory) abort
  let directory = (a:directory ==# '' ? '' : '/' . a:directory)
  let srcs = filter(map(copy(a:plugins), 'v:val.rtp . directory'),
        \ 'isdirectory(v:val)')
  let stride = 50
  for start in range(0, len(srcs), stride)
    call dein#install#_copy_directories(srcs[start : start + stride-1],
          \ dein#util#_get_runtime_path() . directory)
  endfor
endfunction
function! s:merge_files(plugins, directory) abort
  let files = []
  for plugin in a:plugins
    for file in filter(split(globpath(
          \ plugin.rtp, a:directory.'/**', 1), '\n'),
          \ '!isdirectory(v:val)')
      let files += readfile(file, ':t')
    endfor
  endfor

  if !empty(files)
    call dein#util#_writefile(printf('.dein/%s/%s.vim',
          \ a:directory, a:directory), files)
  endif
endfunction
function! s:list_directory(directory) abort
  return dein#util#_globlist(a:directory . '/*')
endfunction
function! s:save_rollback() abort
  let revisions = {}
  for plugin in filter(values(dein#get()), 's:check_rollback(v:val)')
    let rev = s:get_revision_number(plugin)
    if rev !=# ''
      let revisions[plugin.name] = rev
    endif
  endfor

  let dest = s:get_rollback_directory() . '/' . strftime('%Y%m%d%H%M%S')
  call writefile([dein#_vim2json(revisions)], dest)
endfunction
function! s:get_rollback_directory() abort
  let parent = printf('%s/rollbacks/%s',
        \ dein#util#_get_cache_path(), fnamemodify(v:progname, ':r'))
  if !isdirectory(parent)
    call mkdir(parent, 'p')
  endif

  return parent
endfunction
function! s:check_rollback(plugin) abort
  return !has_key(a:plugin, 'local')
        \ && !get(a:plugin, 'frozen', 0)
        \ && get(a:plugin, 'rev', '') ==# ''
endfunction
function! s:generate_ftplugin() abort
  " Create after/ftplugin
  let after = dein#util#_get_runtime_path() . '/after/ftplugin'
  if !isdirectory(after)
    call mkdir(after, 'p')
  endif

  " Merge g:dein#_ftplugin
  let ftplugin = {}
  for [key, string] in items(g:dein#_ftplugin)
    for ft in (key ==# '_' ? ['_'] : split(key, '_'))
      if !has_key(ftplugin, ft)
        let ftplugin[ft] = (ft ==# '_') ? [] : [
              \ "if exists('b:undo_ftplugin')",
              \ "  let b:undo_ftplugin .= '|'",
              \ 'else',
              \ "  let b:undo_ftplugin = ''",
              \ 'endif',
              \ ]
      endif
      let ftplugin[ft] += split(string, '\n')
    endfor
  endfor

  if empty(ftplugin)
    return
  endif

  " Generate ftplugin.vim
  let base = get(split(globpath(&runtimepath, 'ftplugin.vim'), '\n'), 0, '')
  if base !=# ''
    call writefile(readfile(base) + [
          \ 'autocmd filetypeplugin FileType * call s:AfterFTPlugin()',
          \ 'function! s:AfterFTPlugin()',
          \ ] + get(ftplugin, '_', []) + ['endfunction'],
          \ dein#util#_get_runtime_path() . '/ftplugin.vim')
  endif

  " Generate after/ftplugin
  for [filetype, list] in items(ftplugin)
    call writefile(list, printf('%s/%s.vim', after, filetype))
  endfor
endfunction

function! dein#install#_is_async() abort
  return (has('timers') && g:dein#install_max_processes > 1) ?
        \ dein#install#_has_job() : 0
endfunction
function! dein#install#_has_job() abort
  return has('nvim') || (has('patch-8.0.0027') && has('job'))
endfunction

function! dein#install#_remote_plugins() abort
  if !has('nvim')
    return
  endif

  " Load not loaded neovim remote plugins
  let remote_plugins = filter(values(dein#get()),
        \ "isdirectory(v:val.rtp . '/rplugin')")

  call dein#autoload#_source(remote_plugins)

  let &runtimepath = dein#util#_join_rtp(dein#util#_uniq(
        \ dein#util#_split_rtp(&runtimepath)), &runtimepath, '')

  if exists(':UpdateRemotePlugins')
    UpdateRemotePlugins
  endif
endfunction

function! dein#install#_each(cmd, plugins) abort
  let plugins = filter(dein#util#_get_plugins(a:plugins),
        \ 'isdirectory(v:val.path)')

  let global_context_save = s:global_context

  let context = s:init_context(plugins, 'each', 0)
  call s:init_variables(context)

  let cwd = getcwd()
  try
    for plugin in plugins
      call dein#install#_cd(plugin.path)

      execute '!' . s:args2string(a:cmd)
      if !v:shell_error
        redraw
      endif
    endfor
  catch
    call s:nonskip_error(v:exception . ' ' . v:throwpoint)
    return 1
  finally
    let s:global_context = global_context_save
    call dein#install#_cd(cwd)
  endtry
endfunction
function! dein#install#_build(plugins) abort
  for plugin in filter(dein#util#_get_plugins(a:plugins),
        \ "isdirectory(v:val.path) && has_key(v:val, 'build')")
    call s:print_progress_message('Building: ' . plugin.name)
    call dein#install#_each(plugin.build, plugin)
  endfor
  return v:shell_error
endfunction

function! dein#install#_get_log() abort
  return s:log
endfunction
function! dein#install#_get_updates_log() abort
  return s:updates_log
endfunction
function! dein#install#_get_context() abort
  return s:global_context
endfunction
function! dein#install#_get_progress() abort
  return s:progress
endfunction

function! s:get_progress_message(plugin, number, max) abort
  return printf('(%'.len(a:max).'d/%d) [%-20s] %s',
        \ a:number, a:max, repeat('=', (a:number*20/a:max)), a:plugin.name)
endfunction
function! s:get_plugin_message(plugin, number, max, message) abort
  return printf('(%'.len(a:max).'d/%d) |%-20s| %s',
        \ a:number, a:max, a:plugin.name, a:message)
endfunction
function! s:get_short_message(plugin, number, max, message) abort
  return printf('(%'.len(a:max).'d/%d) %s', a:number, a:max, a:message)
endfunction
function! s:get_sync_command(plugin, update_type, number, max) abort "{{{i
  let type = dein#util#_get_type(a:plugin.type)

  if a:update_type ==# 'check_update'
        \ && has_key(type, 'get_fetch_remote_command')
    let cmd = type.get_fetch_remote_command(a:plugin)
  elseif has_key(type, 'get_sync_command')
    let cmd = type.get_sync_command(a:plugin)
  else
    return ['', '']
  endif

  if empty(cmd)
    return ['', '']
  endif

  let message = s:get_plugin_message(a:plugin, a:number, a:max, string(cmd))

  return [cmd, message]
endfunction
function! s:get_revision_number(plugin) abort
  let type = dein#util#_get_type(a:plugin.type)

  if !isdirectory(a:plugin.path)
        \ || !has_key(type, 'get_revision_number_command')
    return ''
  endif

  let cmd = type.get_revision_number_command(a:plugin)
  if empty(cmd)
    return ''
  endif

  let rev = s:system_cd(cmd, a:plugin.path)

  " If rev contains spaces, it is error message
  if rev =~# '\s'
    call s:error(a:plugin.name)
    call s:error('Error revision number: ' . rev)
    return ''
  elseif rev ==# ''
    call s:error(a:plugin.name)
    call s:error('Empty revision number: ' . rev)
    return ''
  endif
  return rev
endfunction
function! s:get_revision_remote(plugin) abort
  let type = dein#util#_get_type(a:plugin.type)

  if !isdirectory(a:plugin.path)
        \ || !has_key(type, 'get_revision_remote_command')
    return ''
  endif

  let cmd = type.get_revision_remote_command(a:plugin)
  if empty(cmd)
    return ''
  endif

  let rev = s:system_cd(cmd, a:plugin.path)
  " If rev contains spaces, it is error message
  return (rev !~# '\s') ? rev : ''
endfunction
function! s:get_updated_log_message(plugin, new_rev, old_rev) abort
  let type = dein#util#_get_type(a:plugin.type)

  let cmd = has_key(type, 'get_log_command') ?
        \ type.get_log_command(a:plugin, a:new_rev, a:old_rev) : ''
  let log = empty(cmd) ? '' : s:system_cd(cmd, a:plugin.path)
  return log !=# '' ? log :
        \            (a:old_rev  == a:new_rev) ? ''
        \            : printf('%s -> %s', a:old_rev, a:new_rev)
endfunction
function! s:lock_revision(process, context) abort
  let num = a:process.number
  let max = a:context.max_plugins
  let plugin = a:process.plugin

  let plugin.new_rev = s:get_revision_number(plugin)

  let type = dein#util#_get_type(plugin.type)
  if !has_key(type, 'get_revision_lock_command')
    return 0
  endif

  let cmd = type.get_revision_lock_command(plugin)

  if empty(cmd) || plugin.new_rev ==# get(plugin, 'rev', '')
    " Skipped.
    return 0
  elseif type(cmd) == type('') && cmd =~# '^E: '
    " Errored.
    call s:error(plugin.path)
    call s:error(cmd[3:])
    return -1
  endif

  if get(plugin, 'rev', '') !=# ''
    call s:log(s:get_plugin_message(plugin, num, max, 'Locked'))
  endif

  let result = s:system_cd(cmd, plugin.path)
  let status = dein#install#_status()

  if status
    call s:error(plugin.path)
    call s:error(result)
    return -1
  endif
endfunction
function! s:get_updated_message(context, plugins) abort
  if empty(a:plugins)
    return ''
  endif

  return "Updated plugins:\n".
        \ join(map(a:plugins,
        \ "'  ' . v:val.name . (v:val.commit_count == 0 ? ''
        \                     : printf('(%d change%s)',
        \                              v:val.commit_count,
        \                              (v:val.commit_count == 1 ? '' : 's')))
        \    . ((a:context.update_type !=# 'check_update'
        \        && v:val.old_rev !=# ''
        \        && v:val.uri =~# '^\\h\\w*://github.com/') ? \"\\n\"
        \      . printf('    %s/compare/%s...%s',
        \        substitute(substitute(v:val.uri, '\\.git$', '', ''),
        \          '^\\h\\w*:', 'https:', ''),
        \        v:val.old_rev, v:val.new_rev) : '')")
        \ , "\n")
endfunction
function! s:get_errored_message(plugins) abort
  if empty(a:plugins)
    return ''
  endif

  let msg = "Error installing plugins:\n".join(
        \ map(copy(a:plugins), "'  ' . v:val.name"), "\n")
  let msg .= "\n"
  let msg .= "Please read the error message log with the :message command.\n"

  return msg
endfunction


" Helper functions
function! dein#install#_cd(path) abort
  if !isdirectory(a:path)
    return
  endif

  try
    execute (haslocaldir() ? 'lcd' : 'cd') fnameescape(a:path)
  catch
    call s:error('Error cd to: ' . a:path)
    call s:error('Current directory: ' . getcwd())
    call s:error(v:exception)
    call s:error(v:throwpoint)
  endtry
endfunction
function! dein#install#_system(command) abort
  if !dein#install#_has_job() && !has('nvim') && type(a:command) == type([])
    " system() does not support List arguments in Vim.
    let command = s:args2string(a:command)
  else
    let command = a:command
  endif

  let command = s:iconv(command, &encoding, 'char')

  let output = dein#install#_has_job() ?
        \ s:job_system.system(command) :
        \ system(command)
  let output = s:iconv(output, 'char', &encoding)
  return substitute(output, '\n$', '', '')
endfunction
function! dein#install#_status() abort
  return dein#install#_has_job() ? s:job_system.status : v:shell_error
endfunction
function! s:system_cd(command, path) abort
  let cwd = getcwd()
  try
    call dein#install#_cd(a:path)
    return dein#install#_system(a:command)
  finally
    call dein#install#_cd(cwd)
  endtry
  return ''
endfunction

let s:job_system = {}
function! s:job_system.on_out(id, msg, event) abort
  let lines = a:msg
  if !empty(lines) && lines[0] !=# "\n" && !empty(s:job_system.candidates)
    " Join to the previous line
    let s:job_system.candidates[-1] .= lines[0]
    call remove(lines, 0)
  endif

  let s:job_system.candidates += lines
endfunction
function! s:job_system.system(command) abort
  let s:job_system.status = -1
  let s:job_system.candidates = []

  let job = dein#job#start(a:command, {'on_stdout': self.on_out})

  call job.wait()
  let s:job_system.status = job.exitval()

  return join(self.candidates, "\n")
endfunction

function! dein#install#_rm(path) abort
  if !isdirectory(a:path) && !filereadable(a:path)
    return
  endif

  if has('patch-7.4.1120')
    try
      call delete(a:path, 'rf')
    catch
      call s:error('Error deleting directory: ' . a:path)
      call s:error(v:exception)
      call s:error(v:throwpoint)
    endtry
  else
    let cmdline = ' "' . a:path . '"'
    if dein#util#_is_windows()
      " Note: In rm command, must use "\" instead of "/".
      let cmdline = substitute(cmdline, '/', '\\\\', 'g')
    endif

    let rm_command = dein#util#_is_windows() ? 'rmdir /S /Q' : 'rm -rf'
    let result = dein#install#_system(rm_command . cmdline)
    if dein#install#_status()
      call dein#util#_error(result)
    endif
  endif
endfunction
function! dein#install#_copy_directories(srcs, dest) abort
  if empty(a:srcs)
    return 0
  endif

  let status = 0
  if dein#util#_is_windows()
    let temp = tempname() . '.bat'
    let exclude = tempname()
    try
      call writefile(['.git', '.svn'], exclude)

      " Create temporary batch file
      let lines = ['@echo off']
      for src in a:srcs
        " Note: In xcopy command, must use "\" instead of "/".
        call add(lines, printf('xcopy /EXCLUDE:%s %s /E /H /I /R /Y /Q',
              \   substitute(exclude, '/', '\\', 'g'),
              \   substitute(printf(' "%s/"* "%s"', src, a:dest),
              \              '/', '\\', 'g')))
      endfor
      call writefile(lines, temp)

      " Note: "xcopy" is slow in Vim8 job.
      let result = dein#install#_system(temp)
    finally
      call delete(temp)
      call delete(exclude)
    endtry
    let status = dein#install#_status()
    if status
      call dein#util#_error('copy command failed.')
      call dein#util#_error(s:iconv(result, 'char', &encoding))
      call dein#util#_error('cmdline: ' . temp)
      call dein#util#_error('tempfile: ' . string(lines))
    endif
  else
    let srcs = map(filter(copy(a:srcs),
          \ 'len(s:list_directory(v:val))'), 'shellescape(v:val . ''/'')')
    let is_rsync = executable('rsync')
    if is_rsync
      let cmdline = printf("rsync -a -q --exclude '/.git/' %s %s",
            \ join(srcs), shellescape(a:dest))
      let result = dein#install#_system(cmdline)
      let status = dein#install#_status()
    else
      for src in srcs
        let cmdline = printf('cp -Ra %s* %s', src, shellescape(a:dest))
        let result = dein#install#_system(cmdline)
        let status = dein#install#_status()
        if status
          break
        endif
      endfor
    endif
    if status
      call dein#util#_error('copy command failed.')
      call dein#util#_error(result)
      call dein#util#_error('cmdline: ' . cmdline)
    endif
  endif

  return status
endfunction

function! s:install_blocking(context) abort
  try
    while 1
      call s:check_loop(a:context)

      if empty(a:context.processes)
            \ && a:context.number == a:context.max_plugins
        break
      endif
    endwhile
  finally
    call s:done(a:context)
  endtry


  return len(a:context.errored_plugins)
endfunction
function! s:install_async(context) abort
  if empty(a:context)
    return
  endif

  call s:check_loop(a:context)

  if empty(a:context.processes)
        \ && a:context.number == a:context.max_plugins
    call s:done(a:context)
  elseif a:context.number != a:context.prev_number
        \ && a:context.number < len(a:context.plugins)
    let plugin = a:context.plugins[a:context.number]
    call s:print_progress_message(
          \ s:get_progress_message(plugin,
          \   a:context.number, a:context.max_plugins))
    let a:context.prev_number = a:context.number
  endif

  return len(a:context.errored_plugins)
endfunction
function! s:check_loop(context) abort
  while a:context.number < a:context.max_plugins
        \ && len(a:context.processes) < g:dein#install_max_processes

    let plugin = a:context.plugins[a:context.number]
    call s:sync(plugin, a:context)

    if !a:context.async
      call s:print_progress_message(
            \ s:get_progress_message(plugin,
            \   a:context.number, a:context.max_plugins))
    endif
  endwhile

  for process in a:context.processes
    call s:check_output(a:context, process)
  endfor

  " Filter eof processes.
  call filter(a:context.processes, '!v:val.eof')
endfunction
function! s:restore_view(context) abort
  if a:context.progress_type ==# 'tabline'
    let &g:showtabline = a:context.showtabline
    let &g:tabline = a:context.tabline
  elseif a:context.progress_type ==# 'title'
    let &g:title = a:context.title
    let &g:titlestring = a:context.titlestring
  endif
endfunction
function! s:init_context(plugins, update_type, async) abort
  let context = {}
  let context.update_type = a:update_type
  let context.async = a:async
  let context.synced_plugins = []
  let context.errored_plugins = []
  let context.processes = []
  let context.number = 0
  let context.prev_number = -1
  let context.plugins = a:plugins
  let context.max_plugins = len(context.plugins)
  let context.progress_type = has('vim_starting') ?
        \ 'echo' : g:dein#install_progress_type
  if !has('nvim') && context.progress_type ==# 'title'
    let context.progress_type = 'echo'
  endif
  let context.message_type = has('vim_starting') ?
        \ 'echo' : g:dein#install_message_type
  let context.laststatus = &g:laststatus
  let context.showtabline = &g:showtabline
  let context.tabline = &g:tabline
  let context.title = &g:title
  let context.titlestring = &g:titlestring
  return context
endfunction
function! s:init_variables(context) abort
  let s:progress = ''
  let s:global_context = a:context
  let s:log = []
  let s:updates_log = []
endfunction
function! s:start() abort
  call s:notify(strftime('Update started: (%Y/%m/%d %H:%M:%S)'))
endfunction
function! s:done(context) abort
  call s:restore_view(a:context)

  call s:notify(s:get_updated_message(a:context, a:context.synced_plugins))
  call s:notify(s:get_errored_message(a:context.errored_plugins))

  if a:context.update_type !=# 'check_update'
    call dein#install#_recache_runtimepath()
  endif
  call s:notify(strftime('Done: (%Y/%m/%d %H:%M:%S)'))

  " Disable installation handler
  let s:global_context = {}
  let s:progress = ''
  augroup dein-install
    autocmd!
  augroup END
  if exists('s:timer')
    call timer_stop(s:timer)
    unlet s:timer
  endif
endfunction

function! s:sync(plugin, context) abort
  let a:context.number += 1

  let num = a:context.number
  let max = a:context.max_plugins

  if isdirectory(a:plugin.path) && get(a:plugin, 'frozen', 0)
    " Skip frozen plugin
    call s:updates_log(s:get_plugin_message(
          \ a:plugin, num, max, 'is frozen.'))
    return
  endif

  let [cmd, message] = s:get_sync_command(
        \   a:plugin, a:context.update_type,
        \   a:context.number, a:context.max_plugins)

  if empty(cmd)
    " Skip
    call s:updates_log(
          \ s:get_plugin_message(a:plugin, num, max, message))
    return
  endif

  if type(cmd) == type('') && cmd =~# '^E: '
    " Errored.

    call s:print_progress_message(s:get_plugin_message(
          \ a:plugin, num, max, 'Error'))
    call s:error(cmd[3:])
    call add(a:context.errored_plugins,
          \ a:plugin)
    return
  endif

  if !a:context.async
    call s:print_progress_message(message)
  endif

  let process = s:init_process(a:plugin, a:context, cmd)
  if !empty(process)
    call add(a:context.processes, process)
  endif
endfunction
function! s:init_process(plugin, context, cmd) abort
  let process = {}

  let cwd = getcwd()
  let lang_save = $LANG
  let prompt_save = $GIT_TERMINAL_PROMPT
  try
    let $LANG = 'C'
    " Disable git prompt (git version >= 2.3.0)
    let $GIT_TERMINAL_PROMPT = 0

    call dein#install#_cd(a:plugin.path)

    let rev = s:get_revision_number(a:plugin)

    let process = {
          \ 'number': a:context.number,
          \ 'max_plugins': a:context.max_plugins,
          \ 'rev': rev,
          \ 'plugin': a:plugin,
          \ 'output': '',
          \ 'status': -1,
          \ 'eof': 0,
          \ 'installed': isdirectory(a:plugin.path),
          \ }

    if isdirectory(a:plugin.path)
          \ && !get(a:plugin, 'local', 0)
      let rev_save = get(a:plugin, 'rev', '')
      try
        " Force checkout HEAD revision.
        " The repository may be checked out.
        let a:plugin.rev = ''

        call s:lock_revision(process, a:context)
      finally
        let a:plugin.rev = rev_save
      endtry
    endif

    call s:init_job(process, a:context, a:cmd)
  finally
    let $LANG = lang_save
    let $GIT_TERMINAL_PROMPT = prompt_save
    call dein#install#_cd(cwd)
  endtry

  return process
endfunction
function! s:init_job(process, context, cmd) abort
  if a:context.async
    let cmd = s:iconv(a:cmd, &encoding, 'char')
    if has('nvim')
      " Use neovim async jobs
      let a:process.job = dein#job#start(cmd, {
            \ 'on_stdout': function('s:job_handler_neovim'),
            \ 'on_stderr': function('s:job_handler_neovim'),
            \ })
      let a:process.id = a:process.job._id
    else
      let a:process.job = dein#job#start(cmd, {
            \   'on_stdout': function('s:job_handler_vim'),
            \   'on_stderr': function('s:job_handler_vim'),
            \ })
      let a:process.id = s:channel2id(job_getchannel(a:process.job._job))
    endif
  else
    let a:process.output = dein#install#_system(a:cmd)
    let a:process.status = dein#install#_status()
  endif

  let a:process.start_time = localtime()
endfunction
function! s:job_handler_neovim(job_id, data, event) abort
  call s:job_handler(a:job_id, a:data, a:event)
endfunction
function! s:job_handler_vim(channel, msg, event) abort
  call s:job_handler(s:channel2id(a:channel), a:msg, '')
endfunction
function! s:job_handler(id, msg, event) abort
  if !has_key(s:job_info, a:id)
    let s:job_info[a:id] = {
          \ 'candidates': [],
          \ 'eof': 0,
          \ }
  endif

  let candidates = s:job_info[a:id].candidates
  let lines = a:msg
  if !empty(lines) && lines[0] !=# "\n" && !empty(candidates)
    " Join to the previous line
    let candidates[-1] .= lines[0]
    call remove(lines, 0)
  endif

  let candidates += lines
endfunction
function! s:check_output(context, process) abort
  if a:context.async
    let [is_timeout, is_skip, status] = s:get_async_result(a:process)
  else
    let [is_timeout, is_skip, status] = [0, 0, a:process.status]
  endif

  if is_skip && !is_timeout
    return
  endif

  let num = a:process.number
  let max = a:context.max_plugins
  let plugin = a:process.plugin

  if isdirectory(plugin.path)
        \ && get(plugin, 'rev', '') !=# ''
        \ && !get(plugin, 'local', 0)
    " Restore revision.
    call s:lock_revision(a:process, a:context)
  endif

  let new_rev = (a:context.update_type ==# 'check_update') ?
        \ s:get_revision_remote(plugin) :
        \ s:get_revision_number(plugin)

  if is_timeout || status
    call s:log(s:get_plugin_message(plugin, num, max, 'Error'))
    call s:error(plugin.path)
    if !a:process.installed
      if !isdirectory(plugin.path)
        call s:error('Maybe wrong username or repository.')
      elseif isdirectory(plugin.path)
        call s:error('Remove the installed directory:' . plugin.path)
        call dein#install#_rm(plugin.path)
      endif
    endif

    call s:error((is_timeout ?
          \    strftime('Process timeout: (%Y/%m/%d %H:%M:%S)') :
          \    split(a:process.output, '\n')
          \ ))

    call add(a:context.errored_plugins,
          \ plugin)
  elseif a:process.rev ==# new_rev
        \ || (a:context.update_type ==# 'check_update' && new_rev ==# '')
    if a:context.update_type !=# 'check_update'
      call s:log(s:get_plugin_message(
            \ plugin, num, max, 'Same revision'))
    endif
  else
    call s:log(s:get_plugin_message(plugin, num, max, 'Updated'))

    if a:context.update_type !=# 'check_update'
      let log_messages = split(s:get_updated_log_message(
            \   plugin, new_rev, a:process.rev), '\n')
      let plugin.commit_count = len(log_messages)
      call s:log(map(log_messages,
            \   's:get_short_message(plugin, num, max, v:val)'))
    else
      let plugin.commit_count = 0
    endif

    let plugin.old_rev = a:process.rev
    let plugin.new_rev = new_rev

    let type = dein#util#_get_type(plugin.type)
    let plugin.uri = has_key(type, 'get_uri') ?
          \ type.get_uri(plugin.repo, plugin) : ''

    let cwd = getcwd()
    try
      call dein#call_hook('post_update', plugin)
    finally
      call dein#install#_cd(cwd)
    endtry

    if dein#install#_build([plugin.name])
      call s:log(s:get_plugin_message(plugin, num, max, 'Build failed'))
      call s:error(plugin.path)
      " Remove.
      call add(a:context.errored_plugins, plugin)
    else
      call add(a:context.synced_plugins, plugin)
    endif
  endif

  let a:process.eof = 1
endfunction
function! s:get_async_result(process) abort
  if !has_key(s:job_info, a:process.id)
    return [0, 1, -1]
  endif

  let job = s:job_info[a:process.id]

  " Check job status
  let status = 0
  if a:process.job.wait(5) != -1
    let job.eof = 1
    let status = a:process.job.exitval()
  endif

  let output = join((job.eof ?
        \ job.candidates : job.candidates[: -2]), "\n")
  if output !=# ''
    let a:process.output .= output
    let a:process.start_time = localtime()
    call s:log(s:get_short_message(
          \ a:process.plugin, a:process.number,
          \ a:process.max_plugins, output))
  endif
  let job.candidates = job.eof ? [] : job.candidates[-1:]

  let is_timeout = (localtime() - a:process.start_time)
        \             >= get(a:process.plugin, 'timeout',
        \                    g:dein#install_process_timeout)

  if job.eof
    let is_timeout = 0
    let is_skip = 0
  else
    let is_skip = 1
  endif

  if is_timeout
    call a:process.job.stop()
    let status = -1
  endif

  return [is_timeout, is_skip, status]
endfunction

function! s:iconv(expr, from, to) abort
  if a:from ==# '' || a:to ==# '' || a:from ==? a:to
    return a:expr
  endif

  if type(a:expr) == type([])
    return map(copy(a:expr), 'iconv(v:val, a:from, a:to)')
  else
    let result = iconv(a:expr, a:from, a:to)
    return result !=# '' ? result : a:expr
  endif
endfunction
function! s:print_progress_message(msg) abort
  let msg = dein#util#_convert2list(a:msg)
  if empty(msg) || empty(s:global_context)
    return
  endif

  if s:global_context.progress_type ==# 'tabline'
    set showtabline=2
    let &g:tabline = join(msg, "\n")
  elseif s:global_context.progress_type ==# 'title'
    set title
    let &g:titlestring = join(msg, "\n")
  elseif s:global_context.progress_type ==# 'echo'
    call s:echo(msg, 'echo')
  endif

  call s:log(msg)

  let s:progress = join(msg, "\n")
endfunction
function! s:error(msg) abort
  let msg = dein#util#_convert2list(a:msg)
  if empty(msg)
    return
  endif

  call s:echo(msg, 'error')

  call s:updates_log(msg)
endfunction
function! s:nonskip_error(msg) abort
  let msg = dein#util#_convert2list(a:msg)
  if empty(msg)
    return
  endif

  call s:echo_mode(join(msg, "\n"), 'error')

  call s:updates_log(msg)
endfunction
function! s:notify(msg) abort
  let msg = dein#util#_convert2list(a:msg)
  if empty(msg)
    return
  endif

  if s:global_context.message_type ==# 'echo'
    call dein#util#_notify(a:msg)
  endif

  call s:updates_log(msg)
  let s:progress = join(msg, "\n")
endfunction
function! s:channel2id(channel) abort
  return matchstr(a:channel, '\d\+')
endfunction
function! s:updates_log(msg) abort
  let msg = dein#util#_convert2list(a:msg)

  let s:updates_log += msg
  call s:log(msg)
endfunction
function! s:log(msg) abort
  let msg = dein#util#_convert2list(a:msg)
  let s:log += msg
  call s:append_log_file(msg)
endfunction
function! s:append_log_file(msg) abort
  let logfile = g:dein#install_log_filename
  if logfile ==# ''
    return
  endif

  let msg = a:msg
  " Appends to log file.
  if filereadable(logfile)
    let msg = readfile(logfile) + msg
  endif

  let dir = fnamemodify(logfile, ':h')
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif
  call writefile(msg, logfile)
endfunction


function! s:echo(expr, mode) abort
  let msg = map(filter(dein#util#_convert2list(a:expr), "v:val !=# ''"),
        \ "'[dein] ' .  v:val")
  if empty(msg)
    return
  endif

  if has('vim_starting')
    let m = join(msg, "\n")
    call s:echo_mode(m, a:mode)
    return
  endif

  let more_save = &more
  let showcmd_save = &showcmd
  let ruler_save = &ruler
  try
    set nomore
    set noshowcmd
    set noruler

    let height = max([1, &cmdheight])
    echo ''
    for i in range(0, len(msg)-1, height)
      redraw

      let m = join(msg[i : i+height-1], "\n")
      call s:echo_mode(m, a:mode)
    endfor
  finally
    let &more = more_save
    let &showcmd = showcmd_save
    let &ruler = ruler_save
  endtry
endfunction
function! s:echo_mode(m, mode) abort
  for m in split(a:m, '\r\?\n', 1)
    if !has('vim_starting') && a:mode !=# 'error'
      let m = s:truncate_skipping(m, &columns - 1, &columns/3, '...')
    endif

    if a:mode ==# 'error'
      echohl WarningMsg | echomsg m | echohl None
    elseif a:mode ==# 'echomsg'
      echomsg m
    else
      echo m
    endif
  endfor
endfunction

function! s:truncate_skipping(str, max, footer_width, separator) abort
  let width = strwidth(a:str)
  if width <= a:max
    let ret = a:str
  else
    let header_width = a:max - strwidth(a:separator) - a:footer_width
    let ret = s:strwidthpart(a:str, header_width) . a:separator
          \ . s:strwidthpart_reverse(a:str, a:footer_width)
  endif

  return ret
endfunction
function! s:strwidthpart(str, width) abort
  if a:width <= 0
    return ''
  endif
  let ret = a:str
  let width = strwidth(a:str)
  while width > a:width
    let char = matchstr(ret, '.$')
    let ret = ret[: -1 - len(char)]
    let width -= strwidth(char)
  endwhile

  return ret
endfunction
function! s:strwidthpart_reverse(str, width) abort
  if a:width <= 0
    return ''
  endif
  let ret = a:str
  let width = strwidth(a:str)
  while width > a:width
    let char = matchstr(ret, '^.')
    let ret = ret[len(char) :]
    let width -= strwidth(char)
  endwhile

  return ret
endfunction

function! s:args2string(args) abort
  return type(a:args) == type('') ? a:args :
        \ join(map(copy(a:args), '''"'' . v:val . ''"'''))
endfunction
