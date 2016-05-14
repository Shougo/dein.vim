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

" Global options definition." "{{{
let g:dein#install_max_processes =
      \ get(g:, 'dein#install_max_processes', 8)
let g:dein#install_progress_type =
      \ get(g:, 'dein#install_progress_type', 'statusline')
let g:dein#install_message_type =
      \ get(g:, 'dein#install_message_type', 'echo')
let g:dein#install_process_timeout =
      \ get(g:, 'dein#install_process_timeout', 120)
"}}}

function! dein#install#_update(plugins, update_type, async) abort "{{{
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

  " Set context.
  let context = s:init_context(plugins, a:update_type, a:async)

  if a:async
    if !empty(s:global_context) &&
          \ confirm('The installation has not finished. Cancel now?',
          \         "yes\nNo", 2) != 1
      return
    endif

    call s:init_variables(context)
    call s:start()
    call s:install_async(context)
    augroup dein-install
      autocmd!
      autocmd CursorHold * call s:on_hold()
    augroup END
  else
    call s:init_variables(context)
    call s:start()
    try
      let errored = s:install_blocking(context)
    catch
      call s:error(v:exception)
      call s:error(v:throwpoint)
      return 1
    endtry

    return errored
  endif
endfunction"}}}
function! dein#install#_reinstall(plugins) abort "{{{
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

  call dein#install#_update(dein#util#_convert2list(a:plugins), 0, 1)
endfunction"}}}
function! dein#install#_direct_install(repo, options) abort "{{{
  let options = copy(a:options)
  let options.merged = 0

  let plugin = dein#add(a:repo, options)
  if empty(plugin)
    return
  endif

  call dein#install(plugin.name)
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
endfunction"}}}
function! dein#install#_rollback(date, plugins) abort "{{{
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
    let cmd = type.get_rollback_command(dein#util#_get_type(plugin.type),
          \ revisions[plugin.name])
    call dein#install#_each(cmd, plugin)
  endfor

  call dein#recache_runtimepath()
  call s:error('Rollback to '.fnamemodify(rollbacks[0], ':t').' version.')
endfunction"}}}

function! dein#install#_recache_runtimepath() abort "{{{
  if dein#util#_is_sudo()
    call s:error('"sudo vim" is detected. This feature is disabled.')
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

  filetype off | filetype on
  silent! runtime! plugin/**/*.vim

  call dein#remote_plugins()

  call dein#call_hook('post_source')

  call dein#util#_save_merged_plugins(
        \ sort(map(copy(merged_plugins), 'v:val.name')))

  call s:save_rollback()

  call dein#clear_state()

  call s:notify(strftime('Runtimepath updated: (%Y/%m/%d %H:%M:%S)'))
endfunction"}}}
function! s:clear_runtimepath() abort "{{{
  if dein#util#_get_cache_path() == ''
    call dein#util#_error('Invalid base path.')
    return
  endif

  let parent = printf('%s/temp/%d', dein#util#_get_cache_path(), getpid())
  let dest = parent . '/' . strftime('%Y%m%d%H%M%S')
  if !isdirectory(parent)
    call mkdir(parent, 'p')
  endif
  if rename(dein#util#_get_runtime_path(), dest)
    call dein#util#_error('Rename failed.')
    call dein#util#_error('src=' . dein#util#_get_runtime_path())
    call dein#util#_error('dest=' . dest)
    return
  endif

  " Dummy call to create runtime path
  call dein#util#_get_runtime_path()

  " Remove previous runtime path
  for path in filter(dein#util#_globlist(
        \ dein#util#_get_cache_path().'/temp/*'),
        \   "fnamemodify(v:val, ':t') !=# getpid()")
    call dein#install#_rm(path)
  endfor
endfunction"}}}
function! s:helptags() abort "{{{
  if g:dein#_runtime_path == '' || dein#util#_is_sudo()
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
endfunction"}}}
function! s:copy_files(plugins, directory) abort "{{{
  let directory = (a:directory == '' ? '' : '/' . a:directory)
  let srcs = filter(map(copy(a:plugins), "v:val.rtp . directory"),
        \ 'isdirectory(v:val)')
  call dein#install#_copy_directories(srcs,
        \ dein#util#_get_runtime_path() . directory)
endfunction"}}}
function! s:merge_files(plugins, directory) abort "{{{
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
endfunction"}}}
function! s:list_directory(directory) abort "{{{
  return dein#util#_globlist(a:directory . '/*')
endfunction"}}}
function! s:save_rollback() abort "{{{
  let revisions = {}
  for plugin in filter(values(dein#get()), 's:check_rollback(v:val)')
    let rev = s:get_revision_number(plugin)
    if rev != ''
      let revisions[plugin.name] = rev
    endif
  endfor

  let dest = s:get_rollback_directory() . '/' . strftime('%Y%m%d%H%M%S')
  call writefile([dein#_vim2json(revisions)], dest)
endfunction"}}}
function! s:get_rollback_directory() abort "{{{
  let parent = printf('%s/rollbacks/%s',
        \ dein#util#_get_cache_path(), fnamemodify(v:progname, ':r'))
  if !isdirectory(parent)
    call mkdir(parent, 'p')
  endif

  return parent
endfunction"}}}
function! s:check_rollback(plugin) abort "{{{
  return !has_key(a:plugin, 'local')
        \ && !get(a:plugin, 'frozen', 0)
        \ && get(a:plugin, 'rev', '') == ''
endfunction"}}}
function! s:generate_ftplugin() abort "{{{
  " Create after/ftplugin
  let after = dein#util#_get_runtime_path() . '/after/ftplugin'
  if !isdirectory(after)
    call mkdir(after, 'p')
  endif

  " Merge g:dein#_ftplugin
  let ftplugin = {}
  for [key, string] in items(g:dein#_ftplugin)
    for ft in (key == '_' ? ['_'] : split(key, '_'))
      if !has_key(ftplugin, ft)
        let ftplugin[ft] = (ft == '_') ? [] : [
              \ "if exists('b:undo_ftplugin')",
              \ "  let b:undo_ftplugin .= '|'",
              \ "else",
              \ "  let b:undo_ftplugin = ''",
              \ "endif",
              \ ]
      endif
      let ftplugin[ft] += split(string, '\n')
    endfor
  endfor

  " Generate ftplugin.vim
  let base = get(split(globpath(&runtimepath, 'ftplugin.vim'), '\n'), 0, '')
  if base != ''
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
endfunction"}}}

function! dein#install#_is_async() abort "{{{
  if has('vim_starting') || g:dein#install_max_processes <= 1
    return 0
  endif
  return has('nvim') || (has('job') && has('channel')
        \                && exists('*job_getchannel')
        \                && exists('*job_info'))
endfunction"}}}

function! dein#install#_remote_plugins() abort "{{{
  if !has('nvim')
    return
  endif

  " Load not loaded neovim remote plugins
  call dein#autoload#_source(filter(
        \ values(dein#get()),
        \ "isdirectory(v:val.rtp . '/rplugin')"))

  if exists(':UpdateRemotePlugins')
    UpdateRemotePlugins
  endif
endfunction"}}}

function! dein#install#_each(cmd, plugins) abort "{{{
  let plugins = filter(dein#util#_get_plugins(a:plugins), 'isdirectory(v:val.path)')

  let context = s:init_context(plugins, 'each', 0)
  call s:init_variables(context)

  let cwd = getcwd()
  try
    for plugin in plugins
      call dein#install#_cd(plugin.path)

      if !dein#util#_has_vimproc()
        let output = system(a:cmd)
        if v:shell_error
          call s:print_message(output)
        else
          call s:error(output)
        endif
      else
        call s:vimproc_system(a:cmd)
      endif
    endfor
  catch
    " Build error from vimproc.
    let message = v:exception . ' ' . v:throwpoint
    call s:nonskip_error(message)
    return 1
  finally
    call dein#install#_cd(cwd)
  endtry
endfunction"}}}

function! dein#install#_get_log() abort "{{{
  return s:log
endfunction"}}}
function! dein#install#_get_updates_log() abort "{{{
  return s:updates_log
endfunction"}}}

function! s:get_progress_message(plugin, number, max) abort "{{{
  return printf('(%'.len(a:max).'d/%d) [%-20s] %s',
        \ a:number, a:max, repeat('=', (a:number*20/a:max)), a:plugin.name)
endfunction"}}}
function! s:get_sync_command(plugin, update_type, number, max) abort "{{{i
  let type = dein#util#_get_type(a:plugin.type)

  let cmd = ''
  if a:update_type ==# 'check_update'
        \ && has_key(type, 'get_fetch_remote_command')
    let cmd = type.get_fetch_remote_command(a:plugin)
  elseif has_key(type, 'get_sync_command')
    let cmd = type.get_sync_command(a:plugin)
  endif

  if cmd == ''
    return ['', '']
  endif

  let message = printf('(%'.len(a:max).'d/%d): |%s| %s',
        \ a:number, a:max, a:plugin.name, cmd)

  return [cmd, message]
endfunction"}}}
function! s:get_revision_number(plugin) abort "{{{
  let type = dein#util#_get_type(a:plugin.type)

  if !isdirectory(a:plugin.path)
        \ || !has_key(type, 'get_revision_number_command')
    return ''
  endif

  let cmd = type.get_revision_number_command(a:plugin)
  if cmd == ''
    return ''
  endif

  let cwd = getcwd()
  try
    call dein#install#_cd(a:plugin.path)

    let rev = dein#install#_system(cmd)

    " If rev contains spaces, it is error message
    return (rev !~ '\s') ? rev : ''
  finally
    call dein#install#_cd(cwd)
  endtry
endfunction"}}}
function! s:get_revision_remote(plugin) abort "{{{
  let type = dein#util#_get_type(a:plugin.type)

  if !isdirectory(a:plugin.path)
        \ || !has_key(type, 'get_revision_remote_command')
    return ''
  endif

  let cmd = type.get_revision_remote_command(a:plugin)
  if cmd == ''
    return ''
  endif

  let cwd = getcwd()
  try
    call dein#install#_cd(a:plugin.path)

    let rev = matchstr(dein#install#_system(cmd), '^\S\+')

    " If rev contains spaces, it is error message
    return (rev !~ '\s') ? rev : ''
  finally
    call dein#install#_cd(cwd)
  endtry
endfunction"}}}
function! s:get_updated_log_message(plugin, new_rev, old_rev) abort "{{{
  let cwd = getcwd()
  try
    let type = dein#util#_get_type(a:plugin.type)

    call dein#install#_cd(a:plugin.path)

    let log_command = has_key(type, 'get_log_command') ?
          \ type.get_log_command(a:plugin, a:new_rev, a:old_rev) : ''
    let log = (log_command != '' ?
          \ dein#install#_system(log_command) : '')
    return log != '' ? log :
          \            (a:old_rev  == a:new_rev) ? ''
          \            : printf('%s -> %s', a:old_rev, a:new_rev)
  finally
    call dein#install#_cd(cwd)
  endtry
endfunction"}}}
function! s:lock_revision(process, context) abort "{{{
  let num = a:process.number
  let max = a:context.max_plugins
  let plugin = a:process.plugin

  let plugin.new_rev = s:get_revision_number(plugin)

  let type = dein#util#_get_type(plugin.type)
  if !has_key(type, 'get_revision_lock_command')
    return 0
  endif

  let cwd = getcwd()
  try
    call dein#install#_cd(plugin.path)

    let cmd = type.get_revision_lock_command(plugin)

    if cmd == '' || plugin.new_rev ==# get(plugin, 'rev', '')
      " Skipped.
      return 0
    elseif cmd =~# '^E: '
      " Errored.
      call s:error(plugin.path)
      call s:error(cmd[3:])
      return -1
    endif

    if get(plugin, 'rev', '') != ''
      call s:print_message(
            \ printf('(%'.len(max).'d/%d): |%s| %s',
            \ num, max, plugin.name, 'Locked'))
    endif

    let result = dein#install#_system(cmd)
    let status = dein#install#_get_last_status()
  finally
    call dein#install#_cd(cwd)
  endtry

  if status
    call s:error(plugin.path)
    call s:error(result)
    return -1
  endif
endfunction"}}}
function! s:get_updated_message(context, plugins) abort "{{{
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
        \        && v:val.old_rev != ''
        \        && v:val.uri =~ '^\\h\\w*://github.com/') ? \"\\n\"
        \      . printf('    %s/compare/%s...%s',
        \        substitute(substitute(v:val.uri, '\\.git$', '', ''),
        \          '^\\h\\w*:', 'https:', ''),
        \        v:val.old_rev, v:val.new_rev) : '')")
        \ , "\n")
endfunction"}}}
function! s:get_errored_message(plugins) abort "{{{
  if empty(a:plugins)
    return ''
  endif

  let msg = "Error installing plugins:\n".join(
        \ map(copy(a:plugins), "'  ' . v:val.name"), "\n")
  let msg .= "\n"
  let msg .= "Please read the error message log with the :message command.\n"

  return msg
endfunction"}}}


" Helper functions
function! dein#install#_cd(path) abort "{{{
  if isdirectory(a:path)
    execute (haslocaldir() ? 'lcd' : 'cd') fnameescape(a:path)
  endif
endfunction"}}}
function! dein#install#_system(command) abort "{{{
  let command = s:iconv(a:command, &encoding, 'char')

  let output = dein#util#_has_vimproc() ?
        \ vimproc#system(command) : system(command)

  let output = s:iconv(output, 'char', &encoding)

  return substitute(output, '\n$', '', '')
endfunction"}}}
function! dein#install#_get_last_status() abort "{{{
  return dein#util#_has_vimproc() ? vimproc#get_last_status() : v:shell_error
endfunction"}}}
function! dein#install#_rm(path) abort "{{{
  if !isdirectory(a:path) && !filereadable(a:path)
    return
  endif

  if has('patch-7.4.1120')
    call delete(a:path, 'rf')
  else
    let cmdline = ' "' . a:path . '"'
    if dein#util#_is_windows()
      " Note: In rm command, must use "\" instead of "/".
      let cmdline = substitute(cmdline, '/', '\\\\', 'g')
    endif

    " Use system instead of vimproc#system()
    let rm_command = dein#util#_is_windows() ? 'rmdir /S /Q' : 'rm -rf'
    let result = system(rm_command . cmdline)
    if v:shell_error
      call dein#util#_error(result)
    endif
  endif
endfunction"}}}
function! dein#install#_copy_directories(srcs, dest) abort "{{{
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
        call add(lines, printf('xcopy /EXCLUDE:%s %s /E /H /I /R /Y',
              \   substitute(exclude, '/', '\\', 'g'),
              \   substitute(printf(' "%s/"* "%s"', src, a:dest),
              \              '/', '\\', 'g')))
      endfor
      call writefile(lines, temp)

      let result = system(temp)
    finally
      call delete(temp)
      call delete(exclude)
    endtry
    if v:shell_error
      let status = 1
      call dein#util#_error('copy command failed.')
      call dein#util#_error(s:iconv(result, 'char', &encoding))
      call dein#util#_error('cmdline: ' . temp)
      call dein#util#_error('tempfile: ' . string(lines))
    endif
  else
    let srcs = map(filter(copy(a:srcs),
          \ 'len(s:list_directory(v:val))'), 'shellescape(v:val . "/")')
    let cmdline = printf("rsync -a --exclude '/.git/' %s %s",
          \ join(srcs), shellescape(a:dest))
    let result = dein#install#_system(cmdline)
    if dein#install#_get_last_status()
      let status = 1
      call dein#util#_error('copy command failed.')
      call dein#util#_error(result)
      call dein#util#_error('cmdline: ' . cmdline)
    endif
  endif

  return status
endfunction"}}}

function! s:install_blocking(context) abort "{{{
  try
    while 1
      call s:check_loop(a:context)

      if empty(a:context.processes)
            \ && a:context.number == a:context.max_plugins
        break
      endif
    endwhile
  finally
    call s:restore_view(a:context)
  endtry

  call s:done(a:context)

  return len(a:context.errored_plugins)
endfunction"}}}
function! s:install_async(context) abort "{{{
  call s:check_loop(a:context)

  if empty(a:context.processes)
        \ && a:context.number == a:context.max_plugins
    call s:restore_view(a:context)
    call s:done(a:context)
  endif

  return len(a:context.errored_plugins)
endfunction"}}}
function! s:check_loop(context) abort "{{{
  while a:context.number < a:context.max_plugins
        \ && len(a:context.processes) < g:dein#install_max_processes

    let plugin = a:context.plugins[a:context.number]
    call s:sync(plugin, a:context)
    call s:print_progress_message(
          \ s:get_progress_message(plugin,
          \   a:context.number, a:context.max_plugins))
  endwhile

  for process in a:context.processes
    call s:check_output(a:context, process)
  endfor

  " Filter eof processes.
  call filter(a:context.processes, '!v:val.eof')
endfunction"}}}
function! s:restore_view(context) abort "{{{
  if a:context.progress_type ==# 'statusline'
    let &l:statusline = a:context.statusline
    let &g:laststatus = a:context.laststatus
  elseif a:context.progress_type ==# 'tabline'
    let &g:showtabline = a:context.showtabline
    let &g:tabline = a:context.tabline
  elseif a:context.progress_type ==# 'title'
    let &g:title = a:context.title
    let &g:titlestring = a:context.titlestring
  endif
endfunction"}}}
function! s:init_context(plugins, update_type, async) abort "{{{
  let context = {}
  let context.update_type = a:update_type
  let context.async = a:async
  let context.synced_plugins = []
  let context.errored_plugins = []
  let context.processes = []
  let context.number = 0
  let context.plugins = a:plugins
  let context.max_plugins =
        \ len(context.plugins)
  let context.progress_type = g:dein#install_progress_type
  if (context.progress_type ==# 'statusline' && a:async)
        \ || has('vim_starting')
    let context.progress_type = 'echo'
  endif
  let context.message_type = g:dein#install_message_type
  let context.laststatus = &g:laststatus
  let context.statusline = &l:statusline
  let context.showtabline = &g:showtabline
  let context.tabline = &g:tabline
  let context.title = &g:title
  let context.titlestring = &g:titlestring
  return context
endfunction"}}}
function! s:init_variables(context) abort "{{{
  let s:global_context = a:context
  let s:log = []
  let s:updates_log = []
endfunction"}}}
function! s:start() abort "{{{
  call s:notify(strftime('Update started: (%Y/%m/%d %H:%M:%S)'))
endfunction"}}}
function! s:done(context) abort "{{{
  call s:notify(s:get_updated_message(a:context, a:context.synced_plugins))
  call s:notify(s:get_errored_message(a:context.errored_plugins))

  if a:context.update_type !=# 'check_update'
        \ && (!empty(a:context.synced_plugins)
        \     || !empty(a:context.errored_plugins))
    call dein#install#_recache_runtimepath()
  else
    call s:notify(strftime('Done: (%Y/%m/%d %H:%M:%S)'))
  endif

  " Disable installation handler
  let s:global_context = {}
  augroup dein-install
    autocmd!
  augroup END
endfunction"}}}

function! s:job_handler_neovim(job_id, data, event) abort "{{{
  call s:job_handler(a:job_id, a:data, a:event)
endfunction"}}}
function! s:job_handler_vim(channel, msg) abort "{{{
  call s:job_handler(s:channel2id(a:channel), a:msg, '')
endfunction"}}}
function! s:job_handler(id, msg, event) abort "{{{
  if !has_key(s:job_info, a:id)
    let s:job_info[a:id] = {
          \ 'candidates': [],
          \ 'eof': 0,
          \ 'status': -1,
          \ }
  endif

  let job = s:job_info[a:id]

  if (has('nvim') && a:event ==# 'exit')
    let job.eof = 1
    let job.status = a:msg
    if !empty(s:global_context)
      call s:install_async(s:global_context)
    endif
    return
  endif

  let lines = has('nvim') ?
        \ map(a:msg, "iconv(v:val, 'char', &encoding)") :
        \ split(iconv(a:msg, 'char', &encoding), "\n")

  let candidates = job.candidates
  if !empty(lines) && lines[0] != "\n" && !empty(job.candidates)
    " Join to the previous line
    let candidates[-1] .= lines[0]
    call remove(lines, 0)
  endif

  let candidates += lines
endfunction"}}}

function! s:sync(plugin, context) abort "{{{
  let a:context.number += 1

  let num = a:context.number
  let max = a:context.max_plugins

  if isdirectory(a:plugin.path) && get(a:plugin, 'frozen', 0)
    " Skip frozen plugin
    call s:print_progress_message(
          \ printf('(%'.len(max).'d/%d): |%s| %s',
          \ num, max, a:plugin.name, 'is frozen.'))
    return
  endif

  let [cmd, message] = s:get_sync_command(
        \   a:plugin, a:context.update_type,
        \   a:context.number, a:context.max_plugins)

  if cmd == ''
    " Skip
    call s:print_progress_message(
          \ printf('(%'.len(max).'d/%d): |%s| %s',
          \ num, max, a:plugin.name, message))
    return
  endif

  if cmd =~# '^E: '
    " Errored.

    call s:print_progress_message(
          \ printf('(%'.len(max).'d/%d): |%s| %s',
          \ num, max, a:plugin.name, 'Error'))
    call s:error(cmd[3:])
    call add(a:context.errored_plugins,
          \ a:plugin)
    return
  endif

  call s:print_progress_message(message)

  let process = s:init_process(a:plugin, a:context, cmd)
  if !empty(process)
    call add(a:context.processes, process)
  endif
endfunction"}}}
function! s:init_process(plugin, context, cmd) abort "{{{
  let process = {}

  let cwd = getcwd()
  let cmd = s:iconv(a:cmd, &encoding, 'char')
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
          \ 'rev': rev,
          \ 'plugin': a:plugin,
          \ 'output': '',
          \ 'status': -1,
          \ 'eof': 0,
          \ 'start_time': localtime(),
          \ }

    if isdirectory(a:plugin.path)
          \ && get(a:plugin, 'rev', '') != ''
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

    call s:init_job(process, a:context, cmd)
  finally
    let $LANG = lang_save
    let $GIT_TERMINAL_PROMPT = prompt_save
    call dein#install#_cd(cwd)
  endtry

  return process
endfunction"}}}
function! s:init_job(process, context, cmd) abort "{{{
  if has('nvim') && a:context.async
    " Use neovim async jobs
    let a:process.proc = jobstart(a:cmd, {
          \ 'on_stdout': function('s:job_handler_neovim'),
          \ 'on_stderr': function('s:job_handler_neovim'),
          \ 'on_exit': function('s:job_handler_neovim'),
          \ })
  elseif has('job') && a:context.async
    try
      " Note: In Windows, job_start() does not work in shellslash.
      let shellslash = 0
      if exists('+shellslash')
        let shellslash = &shellslash
        set noshellslash
      endif
      let a:process.job = job_start([&shell, &shellcmdflag, a:cmd], {
            \   'callback': function('s:job_handler_vim'),
            \ })
    finally
      if exists('+shellslash')
        let &shellslash = shellslash
      endif
    endtry
    let a:process.proc = s:channel2id(job_getchannel(a:process.job))
  elseif dein#util#_has_vimproc()
    let a:process.proc = vimproc#pgroup_open(a:cmd, 0, 2)

    " Close handles.
    call a:process.proc.stdin.close()
    call a:process.proc.stderr.close()
  else
    let a:process.output = dein#install#_system(a:cmd)
    let a:process.status = dein#install#_get_last_status()
  endif
endfunction"}}}
function! s:check_output(context, process) abort "{{{
  let is_timeout = (localtime() - a:process.start_time)
        \             >= get(a:process.plugin, 'timeout',
        \                    g:dein#install_process_timeout)

  if a:context.async && has_key(a:process, 'proc')
    let [is_skip, status] =
          \ s:get_async_result(a:process, is_timeout)
  elseif dein#util#_has_vimproc() && has_key(a:process, 'proc')
    let [is_skip, status] =
          \ s:get_vimproc_result(a:process, is_timeout)
  else
    let [is_skip, status] = [0, a:process.status]
  endif

  if is_skip
    return
  endif

  let num = a:process.number
  let max = a:context.max_plugins
  let plugin = a:process.plugin

  if isdirectory(plugin.path)
        \ && get(plugin, 'rev', '') != ''
        \ && !get(plugin, 'local', 0)
    " Restore revision.
    call s:lock_revision(a:process, a:context)
  endif

  let new_rev = (a:context.update_type ==# 'check_update') ?
        \ s:get_revision_remote(plugin) :
        \ s:get_revision_number(plugin)

  if is_timeout || status
    let message = printf('(%'.len(max).'d/%d): |%s| %s',
          \ num, max, plugin.name, 'Error')
    call s:print_progress_message(message)
    call s:error(plugin.path)
    if !isdirectory(plugin.path)
      call s:error('Maybe wrong username or repository.')
    endif

    call s:error((is_timeout ? 'Process timeout.' :
          \    split(a:process.output, '\n')))

    call add(a:context.errored_plugins,
          \ plugin)
  elseif a:process.rev ==# new_rev
        \ || (a:context.update_type ==# 'check_update' && new_rev == '')
    if a:context.update_type !=# 'check_update'
      call s:print_message(
            \ printf('(%'.len(max).'d/%d): |%s| %s',
            \ num, max, plugin.name, 'Same revision'))
    endif
  else
    call s:print_message(
          \ printf('(%'.len(max).'d/%d): |%s| %s',
          \ num, max, plugin.name, 'Updated'))

    if a:process.rev != '' && a:context.update_type !=# 'check_update'
      let log_messages = split(s:get_updated_log_message(
            \   plugin, new_rev, a:process.rev), '\n')
      let plugin.commit_count = len(log_messages)
      call s:print_message(
            \  map(log_messages, "printf('|%s| ' .
            \   substitute(v:val, '%', '%%', 'g'), plugin.name)"))
    else
      let plugin.commit_count = 0
    endif

    let plugin.old_rev = a:process.rev
    let plugin.new_rev = new_rev

    let type = dein#util#_get_type(plugin.type)
    let plugin.uri = has_key(type, 'get_uri') ?
          \ type.get_uri(plugin.repo, plugin) : ''

    call dein#call_hook('post_update', plugin)
    if s:build(plugin)
          \ && confirm('Build failed. Uninstall "'
          \   .plugin.name.'" now?', "yes\nNo", 2) == 1
      " Remove.
      call dein#install#_rm(plugin.path)
    else
      call add(a:context.synced_plugins, plugin)
    endif
  endif

  let a:process.eof = 1
endfunction"}}}
function! s:get_async_result(process, is_timeout) abort "{{{
  if !has_key(s:job_info, a:process.proc)
    return [1, -1]
  endif

  let job = s:job_info[a:process.proc]

  if !has('nvim')
    " Check job status
    let status = job_status(a:process.job)
    if status !=# 'run'
      let job.status = job_info(a:process.job).exitval
      let job.eof = 1
    endif
  endif

  if !job.eof && !a:is_timeout
    let output = join(job.candidates[: -2], "\n")
    if output != ''
      let a:process.output .= output
      call s:print_message(output)
    endif
    let job.candidates = job.candidates[-1:]
    return [1, -1]
  else
    if a:is_timeout
      silent! call call(
            \ (has('nvim') ? 'jobstop' : 'job_stop'),
            \ (has('nvim') ? a:process.proc : a:process.job))
    endif
    let output = join(job.candidates, "\n")
    if output != ''
      let a:process.output .= output
      call s:print_message(output)
    endif
    let a:process.output = substitute(
          \ a:process.output, 'DETACH', '', '')
    let job.candidates = []
  endif

  let status = job.status

  return [0, status]
endfunction"}}}
function! s:get_vimproc_result(process, is_timeout) abort "{{{
  let output = vimproc#util#iconv(
        \ a:process.proc.stdout.read(-1, 300), 'char', &encoding)
  if output != ''
    let a:process.output .= output
    call s:print_message(output)
  endif
  if !a:process.proc.stdout.eof && !a:is_timeout
    return [1, -1]
  endif
  call a:process.proc.stdout.close()

  let status = a:process.proc.waitpid()[1]

  return [0, status]
endfunction"}}}

function! s:iconv(expr, from, to) abort "{{{
  if a:from == '' || a:to == '' || a:from ==? a:to
    return a:expr
  endif
  let result = iconv(a:expr, a:from, a:to)
  return result != '' ? result : a:expr
endfunction"}}}
function! s:print_progress_message(msg) abort "{{{
  let msg = dein#util#_convert2list(a:msg)
  if empty(msg) || empty(s:global_context)
    return
  endif

  if s:global_context.progress_type ==# 'statusline'
    set laststatus=2
    let &l:statusline = join(msg, "\n")
    redrawstatus
  elseif s:global_context.progress_type ==# 'tabline'
    set showtabline=2
    let &g:tabline = join(msg, "\n")
  elseif s:global_context.progress_type ==# 'title'
    set title
    let &g:titlestring = join(msg, "\n")
  elseif s:global_context.progress_type ==# 'echo'
    call s:echo(msg, 'echo')
  endif

  let s:updates_log += msg
  let s:log += msg
endfunction"}}}
function! s:print_message(msg) abort "{{{
  let msg = dein#util#_convert2list(a:msg)
  if empty(msg)
    return
  endif

  if s:global_context.message_type ==# 'echo'
    call s:echo(msg, 'echo')
  endif

  let s:log += msg
endfunction"}}}
function! s:error(msg) abort "{{{
  let msg = dein#util#_convert2list(a:msg)
  if empty(msg)
    return
  endif

  call s:echo(msg, 'error')

  let s:updates_log += msg
  let s:log += msg
endfunction"}}}
function! s:nonskip_error(msg) abort "{{{
  let msg = dein#util#_convert2list(a:msg)
  if empty(msg)
    return
  endif

  call s:echo_mode(join(msg, "\n"), 'error')

  let s:updates_log += msg
  let s:log += msg
endfunction"}}}
function! s:notify(msg) abort "{{{
  let msg = dein#util#_convert2list(a:msg)
  if empty(msg)
    return
  endif

  call dein#util#_notify(a:msg)

  let s:updates_log += msg
  let s:log += msg
endfunction"}}}
function! s:vimproc_system(cmd) abort "{{{
  let proc = vimproc#pgroup_open(a:cmd, 1)

  " Close handles.
  call proc.stdin.close()

  while !proc.stdout.eof
    if !proc.stderr.eof
      " Print error.
      call s:error(proc.stderr.read_lines(-1, 100))
    endif

    call s:print_message(proc.stdout.read_lines(-1, 100))
  endwhile

  while !proc.stderr.eof
    " Print error.
    call s:error(proc.stderr.read_lines(-1, 100))
  endwhile

  call proc.waitpid()
endfunction"}}}
function! s:build(plugin) abort "{{{
  " Environment check.
  let build = get(a:plugin, 'build')
  if type(build) == type({})
    call s:error('Dictionary type of build is no longer supported')
    return 1
  elseif build == ''
    return 0
  endif

  call s:print_progress_message('Building...')

  call dein#install#_each(build, a:plugin)

  return dein#install#_get_last_status()
endfunction"}}}
function! s:channel2id(channel) abort "{{{
  return matchstr(a:channel, '\d\+')
endfunction"}}}

function! s:echo(expr, mode) abort "{{{
  let msg = map(filter(dein#util#_convert2list(a:expr), "v:val != ''"),
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
endfunction"}}}
function! s:echo_mode(m, mode) abort "{{{
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
endfunction"}}}

function! s:truncate_skipping(str, max, footer_width, separator) abort "{{{
  let width = strwidth(a:str)
  if width <= a:max
    let ret = a:str
  else
    let header_width = a:max - strwidth(a:separator) - a:footer_width
    let ret = s:strwidthpart(a:str, header_width) . a:separator
          \ . s:strwidthpart_reverse(a:str, a:footer_width)
  endif

  return ret
endfunction"}}}
function! s:strwidthpart(str, width) abort "{{{
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
endfunction"}}}
function! s:strwidthpart_reverse(str, width) abort "{{{
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
endfunction"}}}

function! s:on_hold() abort "{{{
  if empty(s:global_context)
    return
  endif

  call s:install_async(s:global_context)
  call feedkeys("g\<ESC>", 'n')
endfunction"}}}

" vim: foldmethod=marker
