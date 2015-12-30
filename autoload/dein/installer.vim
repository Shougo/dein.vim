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
        \ map(a:plugins, 'dein#get(v:val)<`2`>')

  let laststatus = &g:laststatus
  let statusline = &l:statusline
  let cwd = getcwd()
  try
    set laststatus=2
    let max = len(plugins)
    let cnt = 1
    for plugin in plugins
      call s:cd(plugin.path)
      let command = s:git.get_sync_command(plugin)
      let &l:statusline = s:get_progress_message(plugin, cnt, max)
      redrawstatus
      call s:system(command)
      let cnt += 1
    endfor
  finally
    call s:cd(cwd)
    let &l:statusline = statusline
    let &g:laststatus = laststatus
  endtry
endfunction"}}}

function! s:system(command) "{{{
  let command = s:iconv(a:command, &encoding, 'char')

  let output = dein#_has_vimproc() ?
        \ vimproc#system(command) : system(command, "\<C-d>")

  let output = s:iconv(output, 'char', &encoding)

  return substitute(output, '\n$', '', '')
endfunction"}}}
function! s:get_last_status() abort "{{{
  return dein#_has_vimproc() ? vimproc#get_last_status() : v:shell_error
endfunction"}}}

function! s:cd(path) abort "{{{
  if isdirectory(a:path)
    execute (haslocaldir() ? 'lcd' : 'cd') fnameescape(a:path)
  endif
endfunction"}}}

" iconv() wrapper for safety.
function! s:iconv(expr, from, to) abort "{{{
  if a:from == '' || a:to == '' || a:from ==? a:to
    return a:expr
  endif
  let result = iconv(a:expr, a:from, a:to)
  return result != '' ? result : a:expr
endfunction"}}}

function! s:get_progress_message(plugin, number, max) "{{{
  return printf('(%'.len(a:max).'d/%d) [%-20s] %s',
        \ a:number, a:max, repeat('=', (a:number*20/a:max)), a:plugin.name)
endfunction"}}}

" vim: foldmethod=marker
