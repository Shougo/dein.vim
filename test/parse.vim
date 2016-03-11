let s:suite = themis#suite('parse')
let s:assert = themis#helper('assert')

let s:path = tempname()

function! s:suite.before_each() abort "{{{
  call dein#_init()
endfunction"}}}

function! s:suite.after_each() abort "{{{
endfunction"}}}

function! s:suite.parse_dict() abort "{{{
  call dein#begin(s:path)

  let plugin = {'name': 'baz'}
  let parsed_plugin = dein#parse#_dict(plugin)
  call s:assert.equals(parsed_plugin.name, 'baz')
  call s:assert.equals(parsed_plugin.base, s:path.'/repos')

  let plugin = {'name': 'baz', 'rtp': 'foo/', 'base': 'bar/'}
  let parsed_plugin = dein#parse#_dict(plugin)
  call s:assert.equals(parsed_plugin.base, 'bar')
  call s:assert.equals(parsed_plugin.rtp, 'bar/baz/foo')
  call s:assert.equals(parsed_plugin.path, 'bar/baz')

  let plugin = {'name': 'baz', 'directory': 'foo'}
  let parsed_plugin = dein#parse#_dict(plugin)
  call s:assert.equals(parsed_plugin.rtp, s:path.'/repos/foo')
  call s:assert.equals(parsed_plugin.path, s:path.'/repos/foo')

  let plugin = {'name': 'baz', 'directory': 'foo', 'rev': 'bar'}
  let parsed_plugin = dein#parse#_dict(plugin)
  call s:assert.equals(parsed_plugin.rtp, s:path.'/repos/foo_bar')
  call s:assert.equals(parsed_plugin.path, s:path.'/repos/foo_bar')

  let plugin = {'name': 'baz', 'if': '1'}
  let parsed_plugin = dein#parse#_dict(plugin)
  call s:assert.equals(parsed_plugin.merged, 0)

  call dein#end()
endfunction"}}}

function! s:suite.name_conversion() abort "{{{
  let g:dein#enable_name_conversion = 1

  let plugin = dein#parse#_dict({'repo':
        \ 'https://github.com/Shougo/dein.vim.git'})
  call s:assert.equals(plugin.name, 'dein')

  let plugin = dein#parse#_dict({'repo':
        \ 'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git'})
  call s:assert.equals(plugin.name, 'qt-syntax')

  let plugin = dein#parse#_dict({'repo':
        \ 'https://bitbucket.org/kh3phr3n/qt-syntax-vim.git'})
  call s:assert.equals(plugin.name, 'qt-syntax')

  let plugin = dein#parse#_dict({'repo':
        \ 'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
        \ 'name': 'vim-qt-syntax'})
  call s:assert.equals(plugin.name, 'vim-qt-syntax')

  let g:dein#enable_name_conversion = 0
endfunction"}}}

" vim:foldmethod=marker:fen:
