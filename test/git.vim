let s:suite = themis#suite('git')
let s:assert = themis#helper('assert')

let s:git = dein#types#git#define()

function! s:suite.protocol() abort "{{{
  " Protocol errors
  call s:assert.equals(s:git.init(
        \ 'http://github.com/Shougo/dein.vim', {}),
        \ {})

  call s:assert.equals(s:git.init(
        \ 'foo://github.com/Shougo/dein.vim', {}),
        \ {})
endfunction"}}}

function! s:suite.init() abort "{{{
  call s:assert.equals(s:git.init(
        \ 'https://github.com/Shougo/dein.vim', {}),
        \ { 'uri': 'https://github.com/Shougo/dein.vim.git',
        \   'type': 'git', 'directory': 'github.com/Shougo/dein.vim' })
  call s:assert.equals(s:git.init(
        \ 'Shougo/dein.vim', {}),
        \ { 'uri': 'https://github.com/Shougo/dein.vim.git',
        \   'type': 'git', 'directory': 'github.com/Shougo/dein.vim' })
  call s:assert.equals(s:git.init(
        \ 'https://github.com:80/Shougo/dein.vim', {}),
        \ { 'uri': 'https://github.com/Shougo/dein.vim.git',
        \   'type': 'git', 'directory': 'github.com/Shougo/dein.vim' })

  call s:assert.equals(s:git.init(
        \ 'L9', {}),
        \ { 'uri': 'https://github.com/vim-scripts/L9.git',
        \   'type': 'git', 'directory': 'github.com/vim-scripts/L9' })

  let g:dein#types#git#default_protocol = 'ssh'

  call s:assert.equals(s:git.init(
        \ 'Shougo/dein.vim', {}),
        \ { 'uri': 'git@github.com:Shougo/dein.vim.git',
        \   'type': 'git', 'directory': 'github.com/Shougo/dein.vim' })

  let g:dein#types#git#default_protocol = 'https'
endfunction"}}}

" vim:foldmethod=marker:fen:
