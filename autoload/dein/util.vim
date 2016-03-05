"=============================================================================
" FILE: util.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

function! dein#util#_error(msg) abort "{{{
  for mes in s:msg2list(a:msg)
    echohl WarningMsg | echomsg '[dein] ' . mes | echohl None
  endfor
endfunction"}}}

function! s:msg2list(expr) abort "{{{
  return type(a:expr) ==# type([]) ? a:expr : split(a:expr, '\n')
endfunction"}}}

