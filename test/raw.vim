" set verbose=1
const s:suite = themis#suite('raw')
const s:assert = themis#helper('assert')

const s:type = dein#types#raw#define()
const s:path = tempname()
const s:base = s:path .. '/repos/'

function! s:suite.protocol() abort
  " Protocol errors
  call s:assert.equals(s:type.init(
        \ 'http://raw.githubusercontent.com/Shougo/'
        \ .. 'shougo-s-github/master/vim/colors/candy.vim', {}),
        \ {})
endfunction

function! s:suite.init() abort
  call dein#begin(s:path)
  call s:assert.equals(s:type.init(
        \ 'https://raw.githubusercontent.com/Shougo/'
        \ .. 'shougo-s-github/master/vim/colors/candy.vim',
        \ #{ script_type: 'colors' }),
        \ #{
        \   type: 'raw',
        \   name: 'candy.vim',
        \   path: s:base .. 'raw.githubusercontent.com/Shougo/'
        \         .. 'shougo-s-github/master/vim/colors',
        \ })
  call dein#end()
endfunction
