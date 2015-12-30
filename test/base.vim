let s:suite = themis#suite('parse')
let s:assert = themis#helper('assert')

let s:path = ''

function! s:suite.before_each() "{{{
  call dein#_init()
endfunction"}}}

function! s:suite.block_normal() "{{{
  call s:assert.equals(dein#begin(s:path), 0)
  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#begin(s:path), 0)
  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.begin_invalid() "{{{
  call s:assert.equals(dein#begin(s:path), 0)
  call s:assert.equals(dein#begin(s:path), 1)

  call dein#_init()
  call s:assert.equals(dein#end(), 1)

  call s:assert.equals(dein#end(), 1)
endfunction"}}}

function! s:suite.end_invalid() "{{{
  call s:assert.equals(dein#end(), 1)
endfunction"}}}

function! s:suite.add_normal() "{{{
  call s:assert.equals(dein#begin(s:path), 0)

  call s:assert.equals(dein#add('foo', {}), 0)
  call s:assert.equals(g:dein#_plugins.foo.name, 'foo')
  call s:assert.equals(dein#add('bar'), 0)
  call s:assert.equals(g:dein#_plugins.bar.name, 'bar')

  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.add_invalid() "{{{
  call s:assert.equals(dein#add('foo'), 1)
endfunction"}}}

function! s:suite.add_ovewrite() "{{{
  call s:assert.equals(dein#begin(s:path), 0)

  call s:assert.equals(dein#add('foo', {}), 0)
  call s:assert.equals(g:dein#_plugins.foo.sourced, 0)

  call s:assert.equals(dein#add('foo', { 'sourced': 1 }), 0)
  call s:assert.equals(g:dein#_plugins.foo.sourced, 1)

  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.get() "{{{
  let plugins = { 'foo': {'name': 'bar'} }

  call dein#begin(s:path)
  call s:assert.equals(dein#add('foo', { 'name': 'bar' }), 0)
  call s:assert.equals(dein#get('bar').name, 'bar')
  call s:assert.equals(dein#add('foo'), 0)
  call s:assert.equals(dein#get('foo').name, 'foo')
  call dein#end()
endfunction"}}}

function! s:suite.expand() "{{{
  call s:assert.equals(dein#_expand('~'),
        \ dein#_substitute_path(fnamemodify('~', ':p')))
  call s:assert.equals(dein#_expand('$HOME'),
        \ dein#_substitute_path($HOME))
endfunction"}}}

" vim:foldmethod=marker:fen:
