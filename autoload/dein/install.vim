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

function! dein#install#_update(plugins, bang, async) abort "{{{
  let plugins = empty(a:plugins) ?
        \ values(dein#get()) :
        \ filter(map(copy(a:plugins), 'dein#get(v:val)'),
        \        '!empty(v:val)')

  if !a:bang
    let plugins = filter(plugins, '!isdirectory(v:val.path)')
  endif

  if empty(plugins)
    call s:error('Target plugins are not found.')
    call s:error('You may have used the wrong plugin name,'.
          \ ' or all of the plugins are already installed.')
    return
  endif

  " Set context.
  let context = s:init_context(plugins, a:bang, a:async)

  if a:async
    if !empty(s:global_context) &&
          \ confirm('The installation has not finished. Cancel now?',
          \         "yes\nNo", 2) != 1
      return
    endif

    call s:init_variables(context)
    call s:install_async(context)
    augroup dein-install
      autocmd!
      autocmd CursorHold * call s:on_hold()
    augroup END
  else
    call s:init_variables(context)
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
  let plugins = map(dein#util#_convert2list(a:plugins), 'dein#get(v:val)')

  for plugin in plugins
    " Remove the plugin
    if plugin.type ==# 'none'
          \ || plugin.local
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

function! dein#install#_recache_runtimepath() abort "{{{
  if dein#util#_is_sudo()
    call s:error('"sudo vim" is detected. This feature is disabled.')
    return
  endif

  " Clear runtime path.
  call s:clear_runtimepath()

  let plugins = values(dein#get())

  call s:copy_files(filter(copy(plugins), 'v:val.merged'), '')

  call s:helptags()

  " Clear ftdetect and after/ftdetect directories.
  call dein#install#_rm(dein#util#_get_runtime_path().'/ftdetect')
  call dein#install#_rm(dein#util#_get_runtime_path().'/after/ftdetect')

  call s:merge_files(plugins, 'ftdetect')
  call s:merge_files(plugins, 'after/ftdetect')

  silent! runtime! ftdetect/**/*.vim
  silent! runtime! plugin/**/*.vim

  call dein#remote_plugins()

  call dein#call_hook('post_source')

  call s:error(strftime('Runtimepath updated: (%Y/%m/%d %H:%M:%S)'))
endfunction"}}}
function! s:clear_runtimepath() abort "{{{
  if dein#util#_get_base_path() == ''
    call dein#util#_error('Invalid base path.')
    return
  endif

  let parent = printf('%s/temp/%d', dein#util#_get_base_path(), getpid())
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
  for path in filter(split(glob(dein#util#_get_base_path().'/temp/*'), "\n"),
        \ "fnamemodify(v:val, ':t') !=# getpid()")
    call dein#install#_rm(path)
  endfor
endfunction"}}}

function! dein#install#_is_async() abort "{{{
  return !has('vim_starting') && (has('nvim')
        \ || (has('job') && exists('*job_getchannel')
        \                && !dein#util#_is_windows()))
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
function! s:get_sync_command(bang, plugin, number, max) abort "{{{i
  let type = dein#util#_get_type(a:plugin.type)

  let cmd = has_key(type, 'get_sync_command') ?
        \ type.get_sync_command(a:plugin) : ''

  if cmd == ''
    return ['', '']
  endif

  let message = printf('(%'.len(a:max).'d/%d): |%s| %s',
        \ a:number, a:max, a:plugin.name, cmd)

  return [cmd, message]
endfunction"}}}
function! s:get_revision_number(plugin) abort "{{{
  let cwd = getcwd()
  let type = dein#util#_get_type(a:plugin.type)

  if !isdirectory(a:plugin.path)
        \ || !has_key(type, 'get_revision_number_command')
    return ''
  endif

  let cmd = type.get_revision_number_command(a:plugin)
  if cmd == ''
    return ''
  endif

  try
    call dein#install#_cd(a:plugin.path)

    let rev = dein#install#_system(cmd)

    if type.name ==# 'vba' || type.name ==# 'raw'
      " If rev is ok, the output is the checksum followed by the filename
      " separated by two spaces.
      let pat = '^[0-9a-f]\+  ' . a:plugin.path . '/' .
            \ fnamemodify(a:plugin.uri, ':t') . '$'
      return (rev =~# pat) ? matchstr(rev, '^[0-9a-f]\+') : ''
    else
      " If rev contains spaces, it is error message
      return (rev !~ '\s') ? rev : ''
    endif
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

    if cmd == '' || plugin.new_rev ==# plugin.rev
      " Skipped.
      return 0
    elseif cmd =~# '^E: '
      " Errored.
      call s:error(plugin.path)
      call s:error(cmd[3:])
      return -1
    endif

    if plugin.rev != ''
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
function! s:get_updated_message(plugins) abort "{{{
  if empty(a:plugins)
    return ''
  endif

  return "\nUpdated plugins:\n".
        \ join(map(a:plugins,
        \ "'  ' . v:val.name . (v:val.commit_count == 0 ? ''
        \                     : printf('(%d change%s)',
        \                              v:val.commit_count,
        \                              (v:val.commit_count == 1 ? '' : 's')))
        \    . (v:val.uri =~ '^\\h\\w*://github.com/' ? \"\\n\"
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

  let msg = "\nError installing plugins:\n".join(
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
        \ vimproc#system(command) : system(command, "\<C-d>")

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
    " Create temporary batch file
    let lines = ['@echo off']
    for src in a:srcs
      " Note: In xcopy command, must use "\" instead of "/".
      let line = substitute(printf(
            \ ' "%s/"* "%s"', src, a:dest), '/', '\\', 'g')
      call add(lines, printf('xcopy %s /E /H /I /R /Y', line))
    endfor

    let temp = tempname() . '.bat'
    try
      call writefile(lines, temp)
      let result = system(temp)
    finally
      call delete(temp)
    endtry
    if v:shell_error
      let status = 1
      call dein#_error('copy command failed.')
      call dein#_error(result)
      call dein#_error('cmdline: ' . temp)
    endif
  else
    " Note: vimproc#system() does not support the command line.
    for src in a:srcs
      let cmdline = printf('cp -R %s/* %s',
            \ shellescape(src), shellescape(a:dest))
      let result = system(cmdline)
      if v:shell_error
        let status = 1
        call dein#_error('copy command failed.')
        call dein#_error(result)
        call dein#_error('cmdline: ' . cmdline)
      endif
    endfor
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

  call s:echomsg(s:get_updated_message(a:context.synced_plugins))

  call s:echomsg(s:get_errored_message(a:context.errored_plugins))

  call dein#install#_recache_runtimepath()

  return len(a:context.errored_plugins)
endfunction"}}}
function! s:install_async(context) abort "{{{
  call s:check_loop(a:context)

  if empty(a:context.processes)
        \ && a:context.number == a:context.max_plugins
    call s:restore_view(a:context)

    call s:echomsg(s:get_updated_message(a:context.synced_plugins))

    call s:echomsg(s:get_errored_message(a:context.errored_plugins))

    call dein#install#_recache_runtimepath()

    " Disable installation handler
    let s:global_context = {}
    augroup dein-install
      autocmd!
    augroup END
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
function! s:init_context(plugins, bang, async) abort "{{{
  let context = {}
  let context.bang = a:bang
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
        \ || (!has('nvim') && a:msg ==# 'DETACH')
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

  if isdirectory(a:plugin.path) && a:plugin.frozen
    " Skip frozen plugin
    call s:print_progress_message(
          \ printf('(%'.len(max).'d/%d): |%s| %s',
          \ num, max, a:plugin.name, 'is frozen.'))
    return
  endif

  let [cmd, message] = s:get_sync_command(
        \   a:context.bang, a:plugin,
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
function! s:init_process(plugin, context, cmd) abort
  let process = {}

  let cwd = getcwd()
  let cmd = s:iconv(a:cmd, &encoding, 'char')
  try
    let lang_save = $LANG
    let $LANG = 'C'

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

    if isdirectory(a:plugin.path) && a:plugin.rev != '' && !a:plugin.local
      let rev_save = a:plugin.rev
      try
        " Force checkout HEAD revision.
        " The repository may be checked out.
        let a:plugin.rev = ''

        call s:lock_revision(process, a:context)
      finally
        let a:plugin.rev = rev_save
      endtry
    endif

    if has('nvim') && a:context.async
      " Use neovim async jobs
      let process.proc = jobstart(cmd, {
            \ 'on_stdout': function('s:job_handler_neovim'),
            \ 'on_stderr': function('s:job_handler_neovim'),
            \ 'on_exit': function('s:job_handler_neovim'),
            \ })
    elseif has('job') && a:context.async
      let process.proc = s:channel2id(job_getchannel(
            \ job_start([&shell, &shellcmdflag, cmd], {
            \   'callback': function('s:job_handler_vim'),
            \ })))
    elseif dein#util#_has_vimproc()
      let process.proc = vimproc#pgroup_open(cmd, 0, 2)

      " Close handles.
      call process.proc.stdin.close()
      call process.proc.stderr.close()
    else
      let process.output = dein#install#_system(cmd)
      let process.status = dein#install#_get_last_status()
    endif
  finally
    let $LANG = lang_save
    call dein#install#_cd(cwd)
  endtry

  return process
endfunction
function! s:check_output(context, process) abort "{{{
  let is_timeout = (localtime() - a:process.start_time)
        \             >= a:process.plugin.timeout

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

  if isdirectory(plugin.path) && plugin.rev != '' && !plugin.local
    " Restore revision.
    call s:lock_revision(a:process, a:context)
  endif

  let new_rev = s:get_revision_number(plugin)

  if is_timeout || status
    let message = printf('(%'.len(max).'d/%d): |%s| %s',
          \ num, max, plugin.name, 'Error')
    call s:print_progress_message(message)
    call s:error(plugin.path)

    call s:error((is_timeout ? 'Process timeout.' :
          \    split(a:process.output, '\n')))

    call add(a:context.errored_plugins,
          \ plugin)
  elseif a:process.rev ==# new_rev
    call s:print_message(
          \ printf('(%'.len(max).'d/%d): |%s| %s',
          \ num, max, plugin.name, 'Same revision'))
  else
    call s:print_message(
          \ printf('(%'.len(max).'d/%d): |%s| %s',
          \ num, max, plugin.name, 'Updated'))

    if a:process.rev != ''
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
            \ (has('nvim') ? 'jobstop' : 'job_stop'), a:process.proc)
    endif
    let output = join(job.candidates, "\n")
    if output != ''
      let a:process.output .= output
      call s:print_message(output)
    endif
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
  else
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

  call s:echo(msg, 'echo')

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
function! s:echomsg(msg) abort "{{{
  let msg = dein#util#_convert2list(a:msg)
  if empty(msg)
    return
  endif

  call s:echo(msg, 'echomsg')

  let s:updates_log += msg
  let s:log += msg
endfunction"}}}
function! s:helptags() abort "{{{
  if empty(s:list_directory(dein#util#_get_tags_path()))
    return
  endif

  try
    call s:copy_files(values(dein#get()), 'doc')

    silent execute 'helptags' fnameescape(dein#util#_get_tags_path())
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

  call dein#util#_writefile(printf('.dein/%s/%s.vim',
        \ a:directory, a:directory), files)
endfunction"}}}
function! s:list_directory(directory) abort "{{{
  return split(glob(a:directory, '/*'), "\n")
endfunction"}}}
function! s:vimproc_system(cmd) abort "{{{
  let proc = vimproc#pgroup_open(a:cmd)

  " Close handles.
  call proc.stdin.close()

  while !proc.stdout.eof
    if !proc.stderr.eof
      " Print error.
      call s:error(proc.stderr.read_lines(-1, 100))
    endif

    call s:print_message(proc.stdout.read_lines(-1, 100))
  endwhile

  if !proc.stderr.eof
    " Print error.
    call s:error(proc.stderr.read_lines(-1, 100))
  endif

  call proc.waitpid()
endfunction"}}}
function! s:build(plugin) abort "{{{
  " Environment check.
  let build = a:plugin.build
  if type(build) == type('')
    let cmd = build
  elseif dein#util#_is_windows() && has_key(build, 'windows')
    let cmd = build.windows
  elseif dein#util#_is_mac() && has_key(build, 'mac')
    let cmd = build.mac
  elseif dein#util#_is_cygwin() && has_key(build, 'cygwin')
    let cmd = build.cygwin
  elseif !dein#util#_is_windows() && has_key(build, 'linux')
        \ && !executable('gmake')
    let cmd = build.linux
  elseif !dein#util#_is_windows() && has_key(build, 'unix')
    let cmd = build.unix
  elseif has_key(build, 'others')
    let cmd = build.others
  else
    return 0
  endif

  call s:print_progress_message('Building...')

  let cwd = getcwd()
  try
    call dein#install#_cd(a:plugin.path)

    if !dein#util#_has_vimproc()
      let result = system(cmd)

      if dein#install#_get_last_status()
        call s:error(result)
      else
        call s:print_message(result)
      endif
    else
      call s:vimproc_system(cmd)
    endif
  catch
    " Build error from vimproc.
    let message = v:exception . ' ' . v:throwpoint
    call s:error(message)

    return 1
  finally
    call dein#install#_cd(cwd)
  endtry

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
    if a:mode ==# 'error'
      echohl WarningMsg | echomsg m | echohl None
    elseif a:mode ==# 'echomsg'
      echomsg m
    else
      echo m
    endif
  endfor
endfunction"}}}

function! s:on_hold() abort "{{{
  if empty(s:global_context)
    return
  endif

  call s:install_async(s:global_context)
  call feedkeys("g\<ESC>", 'n')
endfunction"}}}

" vim: foldmethod=marker
