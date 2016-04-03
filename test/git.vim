let s:suite = themis#suite('git')
let s:assert = themis#helper('assert')

let s:git = dein#types#git#define()
let s:path = tempname()
let s:base = s:path . '/repos/'

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
  call dein#begin(s:path)
  call s:assert.equals(s:git.init(
        \ 'https://github.com/Shougo/dein.vim', {}),
        \ { 'type': 'git',
        \   'path': s:base.'github.com/Shougo/dein.vim' })
  call s:assert.equals(s:git.get_uri(
        \ 'https://github.com/Shougo/dein.vim', {}),
        \ 'https://github.com/Shougo/dein.vim.git')
  call s:assert.equals(s:git.init(
        \ 'Shougo/dein.vim', {}),
        \ { 'type': 'git',
        \   'path': s:base.'github.com/Shougo/dein.vim' })
  call s:assert.equals(s:git.get_uri(
        \ 'Shougo/dein.vim', {}),
        \ 'https://github.com/Shougo/dein.vim.git')
  call s:assert.equals(s:git.init(
        \ 'https://github.com:80/Shougo/dein.vim', {}),
        \ { 'type': 'git',
        \   'path': s:base.'github.com/Shougo/dein.vim' })
  call s:assert.equals(s:git.get_uri(
        \ 'https://github.com:80/Shougo/dein.vim', {}),
        \ 'https://github.com/Shougo/dein.vim.git')

  call s:assert.equals(s:git.init('L9', {}),
        \ { 'type': 'git',
        \   'path': s:base.'github.com/vim-scripts/L9' })
  call s:assert.equals(s:git.get_uri('L9', {}),
        \ 'https://github.com/vim-scripts/L9.git')

  call s:assert.equals(s:git.init(
        \ 'https://bitbucket.org/mortonfox/twitvim.git', {}),
        \ { 'type': 'git',
        \   'path': s:base.'bitbucket.org/mortonfox/twitvim' })
  call s:assert.equals(s:git.get_uri(
        \ 'https://bitbucket.org/mortonfox/twitvim.git', {}),
        \ 'https://bitbucket.org/mortonfox/twitvim.git')
  call s:assert.equals(s:git.init(
        \ 'https://git.code.sf.net/p/atp-vim/code', {}),
        \ { 'type': 'git',
        \   'path': s:base.'git.code.sf.net/p/atp-vim/code' })
  call s:assert.equals(s:git.get_uri(
        \ 'https://git.code.sf.net/p/atp-vim/code', {}),
        \ 'https://git.code.sf.net/p/atp-vim/code.git')

  let g:dein#types#git#default_protocol = 'ssh'

  call s:assert.equals(s:git.init('Shougo/dein.vim', {}),
        \ { 'type': 'git',
        \   'path': s:base.'github.com/Shougo/dein.vim' })
  call s:assert.equals(s:git.get_uri('Shougo/dein.vim', {}),
        \ 'git@github.com:Shougo/dein.vim.git')

  let g:dein#types#git#default_protocol = 'https'
  call dein#end()
endfunction"}}}

" vim:foldmethod=marker:fen:
