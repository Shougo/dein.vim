"=============================================================================
" FILE: installer.vim
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

let s:git = dein#types#git#define()

function! dein#installer#_update(plugins) abort "{{{
  let plugins = empty(a:plugins) ?
        \ values(dein#get()) :
        \ map(copy(a:plugins), 'dein#get(v:val)')

  let laststatus = &g:laststatus
  let statusline = &l:statusline
  let cwd = getcwd()
  try
    set laststatus=2
    let max = len(plugins)
    let cnt = 1
    for plugin in plugins
      call dein#installer#_cd(plugin.path)
      let command = s:git.get_sync_command(plugin)
      call s:print_message(s:get_progress_message(plugin, cnt, max))
      call dein#installer#_system(command)
      let cnt += 1
    endfor
  finally
    call dein#installer#_cd(cwd)
    let &l:statusline = statusline
    let &g:laststatus = laststatus
  endtry

  call dein#remote_plugins()

  call dein#installer#_helptags(plugins)

  let lazy_plugins = filter(values(dein#get()), 'v:val.lazy')
  call s:merge_files(
        \ lazy_plugins, 'ftdetect')
  call s:merge_files(
        \ lazy_plugins, 'after/ftdetect')
endfunction"}}}

function! s:get_progress_message(plugin, number, max) abort "{{{
  return printf('(%'.len(a:max).'d/%d) [%-20s] %s',
        \ a:number, a:max, repeat('=', (a:number*20/a:max)), a:plugin.name)
endfunction"}}}

" Helper functions
function! dein#installer#_cd(path) abort "{{{
  if isdirectory(a:path)
    execute (haslocaldir() ? 'lcd' : 'cd') fnameescape(a:path)
  endif
endfunction"}}}
function! dein#installer#_system(command) abort "{{{
  let command = s:iconv(a:command, &encoding, 'char')

  let output = dein#_has_vimproc() ?
        \ vimproc#system(command) : system(command, "\<C-d>")

  let output = s:iconv(output, 'char', &encoding)

  return substitute(output, '\n$', '', '')
endfunction"}}}
function! dein#installer#_get_last_status() abort "{{{
  return dein#_has_vimproc() ? vimproc#get_last_status() : v:shell_error
endfunction"}}}
function! dein#installer#_helptags(plugins) abort "{{{
  if dein#_is_sudo()
    call s:error('"sudo vim" is detected. This feature is disabled.')
    return
  endif

  let help_dirs = filter(copy(a:plugins), 's:has_doc(v:val.rtp)')
  if empty(help_dirs)
    return
  endif

  try
    call s:update_tags()
    if !has('vim_starting')
      call s:print_message('Helptags: done. '
            \ .len(help_dirs).' plugins processed')
    endif
  catch
    call s:error('Error generating helptags:')
    call s:error(v:exception)
    call s:error(v:throwpoint)
  endtry

  return help_dirs
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
function! s:update_tags() abort "{{{
  let plugins = [{ 'rtp' : dein#_get_runtime_path()}] + values(dein#get())
  call s:copy_files(plugins, 'doc')

  call dein#_writefile('tags_info',
        \ sort(map(values(dein#get()), 'v:val.name')))

  silent execute 'helptags' fnameescape(dein#_get_tags_path())
endfunction"}}}
function! s:copy_files(plugins, directory) abort "{{{
  " Delete old files.
  call s:cleandir(a:directory)

  let files = {}
  for plugins in a:plugins
    for file in filter(split(globpath(
          \ plugins.rtp, a:directory.'/**', 1), '\n'),
          \ '!isdirectory(v:val)')
      let filename = fnamemodify(file, ':t')
      let files[filename] = readfile(file)
    endfor
  endfor

  for [filename, list] in items(files)
    if filename =~# '^tags\%(-.*\)\?$'
      call sort(list)
    endif
    call dein#_writefile(a:directory . '/' . filename, list)
  endfor
endfunction"}}}
function! s:merge_files(plugins, directory) abort "{{{
  " Delete old files.
  call s:cleandir(a:directory)

  let files = []
  for plugin in a:plugins
    for file in filter(split(globpath(
          \ plugin.rtp, a:directory.'/**', 1), '\n'),
          \ '!isdirectory(v:val)')
      let files += readfile(file, ':t')
    endfor
  endfor

  call dein#_writefile(a:directory.'/'.a:directory . '.vim', files)
endfunction"}}}
function! s:cleandir(path) abort "{{{
  let path = dein#_get_runtime_path() . '/' . a:path

  for file in filter(split(globpath(path, '*', 1), '\n'),
        \ '!isdirectory(v:val)')
    call delete(file)
  endfor
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

function! s:has_doc(path) abort "{{{
  return a:path != '' &&
        \ isdirectory(a:path.'/doc')
        \   && (!filereadable(a:path.'/doc/tags')
        \       || filewritable(a:path.'/doc/tags'))
        \   && (!filereadable(a:path.'/doc/tags-??')
        \       || filewritable(a:path.'/doc/tags-??'))
        \   && (glob(a:path.'/doc/*.txt') != ''
        \       || glob(a:path.'/doc/*.??x') != '')
endfunction"}}}

" vim: foldmethod=marker
