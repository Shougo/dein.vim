let s:suite = themis#suite('base')
let s:assert = themis#helper('assert')

let s:path = tempname()

function! s:suite.before_each() abort "{{{
  call dein#_init()
endfunction"}}}

function! s:suite.block_normal() abort "{{{
  call s:assert.equals(dein#begin(s:path), 0)
  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#begin(s:path), 0)
  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.begin_invalid() abort "{{{
  call s:assert.equals(dein#begin(s:path), 0)
  call s:assert.equals(dein#begin(s:path), 1)

  call dein#_init()
  call s:assert.equals(dein#end(), 1)

  call s:assert.equals(dein#end(), 1)
endfunction"}}}

function! s:suite.end_invalid() abort "{{{
  call s:assert.equals(dein#end(), 1)
endfunction"}}}

function! s:suite.add_normal() abort "{{{
  call s:assert.equals(dein#begin(s:path), 0)

  call s:assert.equals(dein#add('foo', {}), 0)
  call s:assert.equals(g:dein#_plugins.foo.name, 'foo')
  call s:assert.equals(dein#add('bar'), 0)
  call s:assert.equals(g:dein#_plugins.bar.name, 'bar')

  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.add_ovewrite() abort "{{{
  call s:assert.equals(dein#begin(s:path), 0)

  call s:assert.equals(dein#add('foo', {}), 0)
  call s:assert.equals(g:dein#_plugins.foo.sourced, 0)

  call s:assert.equals(dein#add('foo', { 'sourced': 1 }), 0)
  call s:assert.equals(g:dein#_plugins.foo.sourced, 1)

  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.get() abort "{{{
  let plugins = { 'foo': {'name': 'bar'} }

  call dein#begin(s:path)
  call s:assert.equals(dein#add('foo', { 'name': 'bar' }), 0)
  call s:assert.equals(dein#get('bar').name, 'bar')
  call s:assert.equals(dein#add('foo'), 0)
  call s:assert.equals(dein#get('foo').name, 'foo')
  call dein#end()
endfunction"}}}

function! s:suite.is_sourced() abort "{{{
  call dein#begin(s:path)
  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)
  call s:assert.equals(dein#is_sourced('neocomplete.vim'), 0)
  call s:assert.equals(dein#install(), 0)
  call s:assert.equals(dein#is_sourced('neocomplete.vim'), 0)
  call s:assert.equals(dein#source('neocomplete.vim'), 0)
  call s:assert.equals(dein#is_sourced('neocomplete.vim'), 1)
  call dein#end()
endfunction"}}}

function! s:suite.expand() abort "{{{
  call s:assert.equals(dein#util#_expand('~'),
        \ dein#util#_substitute_path(fnamemodify('~', ':p')))
  call s:assert.equals(dein#util#_expand('$HOME'),
        \ dein#util#_substitute_path($HOME))
endfunction"}}}

" vim:foldmethod=marker:fen:
