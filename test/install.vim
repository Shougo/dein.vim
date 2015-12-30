let s:suite = themis#suite('parse')
let s:assert = themis#helper('assert')

let s:path = '.cache'

function! s:suite.before_each() abort "{{{
  call dein#_init()
endfunction"}}}

function! s:suite.parse_dict() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call dein#end()
endfunction"}}}

" vim:foldmethod=marker:fen:
