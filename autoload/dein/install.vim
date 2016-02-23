"=============================================================================
" FILE: install.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

function! dein#install#_update(plugins, bang, block) abort "{{{
  let plugins = empty(a:plugins) ?
        \ values(dein#get()) :
        \ map(copy(a:plugins), 'dein#get(v:val)')

  if !a:bang
    let plugins = filter(plugins, '!isdirectory(v:val.path)')
  endif

  call s:install_block(a:bang, plugins)
endfunction"}}}
function! dein#install#_reinstall(plugins) abort "{{{
  let plugins = map(dein#_convert2list(a:plugins), 'dein#get(v:val)')

  for plugin in plugins
    " Remove the plugin
    if plugin.type ==# 'none'
          \ || plugin.local
          \ || (plugin.sourced &&
          \     index(['dein', 'vimproc'], plugin.normalized_name) >= 0)
      call dein#_error(
            \ printf('|%s| Cannot reinstall the plugin!', plugin.name))
      continue
    endif

    " Reinstall.
    call s:print_message(printf('|%s| Reinstalling...', plugin.name))

    if isdirectory(plugin.path)
      call dein#install#_rm(plugin.path)
    endif
  endfor

  call dein#install#_update(dein#_convert2list(a:plugins), 0, 1)
endfunction"}}}

function! dein#install#_recache_runtimepath() abort "{{{
  if dein#_is_sudo()
    call s:error('"sudo vim" is detected. This feature is disabled.')
    return
  endif

  " Clear runtime path.
  call dein#install#_rm(dein#_get_runtime_path())
  call mkdir(dein#_get_runtime_path(), 'p')

  call s:copy_files(filter(values(dein#get()), 'v:val.merged'), '')

  call s:helptags()

  let lazy_plugins = dein#_get_lazy_plugins()

  call s:merge_files(lazy_plugins, 'ftdetect')
  call s:merge_files(lazy_plugins, 'after/ftdetect')

  silent! runtime! ftdetect/**/*.vim
  silent! runtime! after/ftdetect/**/*.vim
  silent! runtime! plugin/**/*.vim
  silent! runtime! after/plugin/**/*.vim

  call dein#remote_plugins()

  call dein#_call_hook('post_source')

  echomsg 'Update done: ' . strftime('(%Y/%m/%d %H:%M:%S)')
endfunction"}}}

function! s:get_progress_message(plugin, number, max) abort "{{{
  return printf('(%'.len(a:max).'d/%d) [%-20s] %s',
        \ a:number, a:max, repeat('=', (a:number*20/a:max)), a:plugin.name)
endfunction"}}}
function! s:get_sync_command(bang, plugin, number, max) abort "{{{i
  let type = dein#_get_type(a:plugin.type)

  let cmd = has_key(type, 'get_sync_command') ?
        \ type.get_sync_command(a:plugin) : ''

  if cmd == ''
    return ['', 'Not supported sync action.']
  endif

  let message = printf('(%'.len(a:max).'d/%d): |%s| %s',
        \ a:number, a:max, a:plugin.name, cmd)

  return [cmd, message]
endfunction"}}}

" Helper functions
function! dein#install#_cd(path) abort "{{{
  if isdirectory(a:path)
    execute (haslocaldir() ? 'lcd' : 'cd') fnameescape(a:path)
  endif
endfunction"}}}
function! dein#install#_system(command) abort "{{{
  let command = s:iconv(a:command, &encoding, 'char')

  let output = dein#_has_vimproc() ?
        \ vimproc#system(command) : system(command, "\<C-d>")

  let output = s:iconv(output, 'char', &encoding)

  return substitute(output, '\n$', '', '')
endfunction"}}}
function! dein#install#_get_last_status() abort "{{{
  return dein#_has_vimproc() ? vimproc#get_last_status() : v:shell_error
endfunction"}}}
function! dein#install#_rm(path) abort "{{{
  if has('patch-7.4.1120')
    call delete(a:path, 'rf')
  else
    let cmdline = ' "' . a:path . '"'
    if dein#_is_windows()
      " Note: In rm command, must use "\" instead of "/".
      let cmdline = substitute(cmdline, '/', '\\\\', 'g')
    endif

    " Use system instead of vimproc#system()
    let rm_command = dein#_is_windows() ? 'rmdir /S /Q' : 'rm -rf'
    let result = system(rm_command . cmdline)
    if v:shell_error
      call dein#_error(result)
    endif
  endif
endfunction"}}}
function! dein#install#_copy_directory(src, dest) abort "{{{
  let cmdline = printf(' "%s/"* "%s"', a:src, a:dest)
  if dein#_is_windows()
    " Note: In xcopy command, must use "\" instead of "/".
    let cmdline = substitute(cmdline, '/', '\\', 'g')
  endif

  " Use system instead of vimproc#system()
  let cmdline = dein#_is_windows() ?
        \ printf('xcopy %s /E /H /I /R /Y', cmdline) :
        \ 'cp -R ' . cmdline
  let result = system(cmdline)
  if v:shell_error
    call dein#_error('copy command failed.')
    call dein#_error(result)
    call dein#_error('cmdline: ' . cmdline)
    return 1
  endif
endfunction"}}}

function! s:install_block(bang, plugins) abort "{{{
  " Set context.
  let context = s:init_context(a:plugins, a:bang)

  let laststatus = &g:laststatus
  let statusline = &l:statusline
  let cwd = getcwd()
  try
    set laststatus=2

    while 1
      while context.number < context.max_plugins
            \ && len(context.processes) < g:dein#install_max_processes

        let plugin = context.plugins[context.number]
        call s:sync(context.plugins[context.number], context)
        call s:print_message(
              \ s:get_progress_message(plugin,
              \   context.number, context.max_plugins))
      endwhile

      for process in context.processes
        call s:check_output(context, process)
      endfor

      " Filter eof processes.
      call filter(context.processes, '!v:val.eof')

      if empty(context.processes)
            \ && context.number == context.max_plugins
        break
      endif
    endwhile
  finally
    call dein#install#_cd(cwd)
    let &l:statusline = statusline
    let &g:laststatus = laststatus
  endtry

  call dein#install#_recache_runtimepath()

  return [context.synced_plugins, context.errored_plugins]
endfunction"}}}
function! s:init_context(plugins, bang) abort "{{{
  let context = {}
  let context.bang = a:bang
  let context.synced_plugins = []
  let context.errored_plugins = []
  let context.processes = []
  let context.number = 0
  let context.plugins = a:plugins
  let context.max_plugins =
        \ len(context.plugins)
  return context
endfunction"}}}
function! s:sync(plugin, context) abort "{{{
  let a:context.number += 1

  let num = a:context.number
  let max = a:context.max_plugins

  if isdirectory(a:plugin.path) && a:plugin.frozen
    " Skip frozen plugin
    call s:print_message(
          \ printf('(%'.len(max).'d/%d): |%s| %s',
          \ num, max, a:plugin.name, 'is frozen.'))
    return
  else
    let [cmd, message] = s:get_sync_command(
          \   a:context.bang, a:plugin,
          \   a:context.number, a:context.max_plugins)
  endif

  if cmd == ''
    " Skip
    call s:print_message(
          \ printf('(%'.len(max).'d/%d): |%s| %s',
          \ num, max, a:plugin.name, message))
    return
  endif

  if cmd =~# '^E: '
    " Errored.

    call s:print_message(
          \ printf('(%'.len(max).'d/%d): |%s| %s',
          \ num, max, a:plugin.name, 'Error'))
    call s:error(cmd[3:])
    call add(a:context.errored_plugins,
          \ a:plugin)
    return
  endif

  call s:print_message(message)

  let cwd = getcwd()
  try
    let lang_save = $LANG
    let $LANG = 'C'

    " Cd to plugin path.
    call dein#install#_cd(a:plugin.path)

    let process = {
          \ 'number' : num,
          \ 'plugin' : a:plugin,
          \ 'output' : '',
          \ 'status' : -1,
          \ 'eof' : 0,
          \ 'start_time' : localtime(),
          \ }

    if dein#_has_vimproc()
      let process.proc = vimproc#pgroup_open(vimproc#util#iconv(
            \            cmd, &encoding, 'char'), 0, 2)

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

  call add(a:context.processes, process)
endfunction"}}}
function! s:check_output(context, process) abort "{{{
  if dein#_has_vimproc() && has_key(a:process, 'proc')
    let is_timeout = (localtime() - a:process.start_time)
          \             >= a:process.plugin.timeout
    let output = vimproc#util#iconv(
          \ a:process.proc.stdout.read(-1, 300), 'char', &encoding)
    if output != ''
      let a:process.output .= output
      call s:print_message(output)
    endif
    if !a:process.proc.stdout.eof && !is_timeout
      return
    endif
    call a:process.proc.stdout.close()

    let status = a:process.proc.waitpid()[1]
  else
    let is_timeout = 0
    let status = a:process.status
  endif

  let num = a:process.number
  let max = a:context.max_plugins
  let plugin = a:process.plugin

  if is_timeout || status
    let message = printf('(%'.len(max).'d/%d): |%s| %s',
          \ num, max, plugin.name, 'Error')
    call s:print_message(message)
    call s:error(plugin.path)

    call s:error(
          \ (is_timeout ? 'Process timeout.' :
          \    split(a:process.output, '\n')))

    call add(a:context.errored_plugins,
          \ plugin)
  else
    call s:print_message(
          \ printf('(%'.len(max).'d/%d): |%s| %s',
          \ num, max, plugin.name, 'Updated'))

    if s:build(plugin)
          \ && confirm('Build failed. Uninstall "'
          \   .plugin.name.'" now?', "yes\nNo", 2) == 1
      " Remove.
      call dein#install#_rm(plugin.path)
    else
      call add(a:context.synced_plugins, plugin)
    endif
    call add(a:context.synced_plugins, plugin)
  endif

  let a:process.eof = 1
endfunction"}}}

function! s:iconv(expr, from, to) abort "{{{
  if a:from == '' || a:to == '' || a:from ==? a:to
    return a:expr
  endif
  let result = iconv(a:expr, a:from, a:to)
  return result != '' ? result : a:expr
endfunction"}}}
function! s:print_message(msg) abort "{{{
  if !has('vim_starting')
    let &l:statusline = a:msg
    redrawstatus
  else
    call s:echo(a:msg, 'echo')
  endif
endfunction"}}}
function! s:error(msg) abort "{{{
  call s:echo(a:msg, 'error')
endfunction"}}}
function! s:helptags() abort "{{{
  if empty(s:list_directory(dein#_get_tags_path()))
    return
  endif

  try
    call s:copy_files(values(dein#get()), 'doc')

    silent execute 'helptags' fnameescape(dein#_get_tags_path())
  catch
    call s:error('Error generating helptags:')
    call s:error(v:exception)
    call s:error(v:throwpoint)
  endtry
endfunction"}}}
function! s:copy_files(plugins, directory) abort "{{{
  let directory = (a:directory == '' ? '' : '/' . a:directory)
  for src in filter(map(copy(a:plugins), "v:val.rtp . directory"),
        \ 'isdirectory(v:val)')
    call dein#install#_copy_directory(src,
          \ dein#_get_runtime_path() . directory)
  endfor
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

  call dein#_writefile(printf('.dein/%s/%s.vim',
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
  elseif dein#_is_windows() && has_key(build, 'windows')
    let cmd = build.windows
  elseif dein#_is_mac() && has_key(build, 'mac')
    let cmd = build.mac
  elseif dein#_is_cygwin() && has_key(build, 'cygwin')
    let cmd = build.cygwin
  elseif !dein#_is_windows() && has_key(build, 'linux')
        \ && !executable('gmake')
    let cmd = build.linux
  elseif !dein#_is_windows() && has_key(build, 'unix')
    let cmd = build.unix
  elseif has_key(build, 'others')
    let cmd = build.others
  else
    return 0
  endif

  call s:print_message('Building...')

  let cwd = getcwd()
  try
    call dein#install#_cd(a:plugin.path)

    if !dein#_has_vimproc()
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
    let message = (v:exception !~# '^Vim:')?
          \ v:exception : v:exception . ' ' . v:throwpoint
    call s:error(message)

    return 1
  finally
    call dein#install#_cd(cwd)
  endtry

  return dein#install#_get_last_status()
endfunction"}}}

function! s:echo(expr, mode) abort "{{{
  let msg = map(dein#_convert2list(a:expr), "'[dein] ' .  v:val")
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

" vim: foldmethod=marker
