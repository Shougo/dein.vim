let s:suite = themis#suite('git')
let s:assert = themis#helper('assert')

let s:type = dein#types#git#define()
let s:path = tempname()
let s:base = s:path . '/repos/'

function! s:suite.protocol() abort
  call dein#begin(s:path)
  " Protocol errors
  call s:assert.equals(s:type.init(
        \ 'http://github.com/Shougo/dein.vim', {}),
        \ {})

  call s:assert.equals(s:type.init(
        \ 'foo://github.com/Shougo/dein.vim', {}),
        \ {})

  call s:assert.equals(s:type.init(
        \ 'https://github.com/vim/vim/archive/master.zip', {}),
        \ {})

  call s:assert.not_equals(s:type.init(
        \ 'test.zip', {}),
        \ {})
  call dein#end()
endfunction

function! s:suite.init() abort
  call dein#begin(s:path)
  call s:assert.equals(s:type.init(
        \ 'https://github.com/Shougo/dein.vim', {}),
        \ { 'type': 'git',
        \   'path': s:base.'github.com/Shougo/dein.vim' })
  call s:assert.equals(s:type.get_uri(
        \ 'https://github.com/Shougo/dein.vim', {}),
        \ 'https://github.com/Shougo/dein.vim.git')
  call s:assert.equals(s:type.init(
        \ 'Shougo/dein.vim', {}),
        \ { 'type': 'git',
        \   'path': s:base.'github.com/Shougo/dein.vim' })
  call s:assert.equals(s:type.get_uri(
        \ 'Shougo/dein.vim', {}),
        \ 'https://github.com/Shougo/dein.vim.git')
  call s:assert.equals(s:type.init(
        \ 'https://github.com:80/Shougo/dein.vim', {}),
        \ { 'type': 'git',
        \   'path': s:base.'github.com/Shougo/dein.vim' })
  call s:assert.equals(s:type.get_uri(
        \ 'https://github.com:80/Shougo/dein.vim', {}),
        \ 'https://github.com/Shougo/dein.vim.git')

  call s:assert.equals(s:type.init('L9', {}),
        \ { 'type': 'git',
        \   'path': s:base.'github.com/vim-scripts/L9' })
  call s:assert.equals(s:type.get_uri('L9', {}),
        \ 'https://github.com/vim-scripts/L9.git')

  call s:assert.equals(s:type.init(
        \ 'https://bitbucket.org/mortonfox/twitvim.git', {}),
        \ { 'type': 'git',
        \   'path': s:base.'bitbucket.org/mortonfox/twitvim' })
  call s:assert.equals(s:type.get_uri(
        \ 'https://bitbucket.org/mortonfox/twitvim.git', {}),
        \ 'https://bitbucket.org/mortonfox/twitvim.git')
  call s:assert.equals(s:type.init(
        \ 'https://git.code.sf.net/p/atp-vim/code', {'type': 'git'}),
        \ { 'type': 'git',
        \   'path': s:base.'git.code.sf.net/p/atp-vim/code' })
  call s:assert.equals(s:type.get_uri(
        \ 'https://git.code.sf.net/p/atp-vim/code', {'type': 'git'}),
        \ 'https://git.code.sf.net/p/atp-vim/code.git')

  call s:assert.equals(s:type.get_uri('git@example.com:vim/snippets', {}),
        \ 'git@example.com:vim/snippets.git')

  let g:dein#types#git#default_protocol = 'ssh'

  call s:assert.equals(s:type.init('Shougo/dein.vim', {}),
        \ { 'type': 'git',
        \   'path': s:base.'github.com/Shougo/dein.vim' })
  call s:assert.equals(s:type.get_uri('Shougo/dein.vim', {}),
        \ 'git@github.com:Shougo/dein.vim.git')

  let g:dein#types#git#default_protocol = 'https'
  call dein#end()
endfunction
