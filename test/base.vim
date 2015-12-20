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

function! s:suite.load_normal() "{{{
  let plugins = { 'foo': {'name': 'bar'} }

  call s:assert.equals(dein#begin(s:path), 0)

  call s:assert.equals(dein#load(plugins), 0)
  call s:assert.equals(g:dein#_plugins.foo.name, 'bar')

  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.load_invalid() "{{{
  call s:assert.equals(dein#load({}), 1)
endfunction"}}}

function! s:suite.load_ovewrite() "{{{
  let plugins1 = { 'foo': {'name': 'baz'}, 'bar': {'name': 'bar'} }

  call s:assert.equals(dein#begin(s:path), 0)

  call s:assert.equals(dein#load(plugins1), 0)

  let plugins2 = { 'foo': {'name': 'baa'} }
  call s:assert.equals(dein#load(plugins2), 0)
  call s:assert.equals(g:dein#_plugins.foo.name, 'baa')
  call s:assert.equals(g:dein#_plugins.bar.name, 'bar')

  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.get() "{{{
  let plugins = { 'foo': {'name': 'bar'} }

  call dein#begin(s:path)
  call s:assert.equals(dein#load(plugins), 0)
  call s:assert.equals(dein#get(), g:dein#_plugins)
  call s:assert.equals(dein#get('foo'), dein#parse#_dict(plugins.foo))
  call s:assert.equals(dein#get('baz'), {})
  call dein#end()
endfunction"}}}

" vim:foldmethod=marker:fen:
