"=============================================================================
" FILE: dein.vim
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

let s:save_cpo = &cpo
set cpo&vim

function! dein#_msg2list(expr) "{{{
  return type(a:expr) ==# type([]) ? a:expr : split(a:expr, '\n')
endfunction"}}}

function! dein#_error(msg) abort "{{{
  for mes in dein#_msg2list(a:msg)
    echohl WarningMsg | echomsg '[dein] ' . mes | echohl None
  endfor
endfunction"}}}

if v:version < 704
  call dein#_error('Does not work this version of Vim (' . v:version . ').')
  let &cpo = s:save_cpo
  unlet s:save_cpo
  finish
endif

" Global options definition." "{{{
"}}}

function! dein#_init() abort "{{{
  let s:block_level = 0
  let g:dein#_plugins = {}
  let g:dein#hooks = {}
endfunction"}}}

call dein#_init()

function! dein#begin() abort "{{{
  if s:block_level != 0
    call dein#_error('Invalid begin/end block usage.')
    return 1
  endif

  let s:block_level += 1
endfunction"}}}

function! dein#end() abort "{{{
  if s:block_level != 1
    call dein#_error('Invalid begin/end block usage.')
    return 1
  endif

  let s:block_level -= 1
endfunction"}}}

function! dein#load(plugins) abort "{{{
  if s:block_level != 1
    call dein#_error('Invalid load usage.')
    return 1
  endif

  call extend(g:dein#_plugins, a:plugins)
endfunction"}}}

function! dein#get(...) abort "{{{
  return empty(a:000) ? copy(g:dein#_plugins) : get(g:dein#_plugins, a:1, {})
endfunction"}}}

function! dein#tap(name) abort "{{{
  
endfunction"}}}

function! dein#untap(name) abort "{{{
  
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
