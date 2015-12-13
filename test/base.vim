let s:suite = themis#suite('parser')
let s:assert = themis#helper('assert')

function! s:suite.before_each() "{{{
  call dein#_init()
endfunction"}}}

function! s:suite.block_normal() "{{{
  call s:assert.equals(dein#begin(), 0)
  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#begin(), 0)
  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.begin_invalid() "{{{
  call s:assert.equals(dein#begin(), 0)
  call s:assert.equals(dein#begin(), 1)

  call dein#_init()
  call s:assert.equals(dein#end(), 1)

  call s:assert.equals(dein#end(), 1)
endfunction"}}}

function! s:suite.end_invalid() "{{{
  call s:assert.equals(dein#end(), 1)
endfunction"}}}

function! s:suite.load_normal() "{{{
  let plugins = { 'foo': 'bar' }

  call s:assert.equals(dein#begin(), 0)

  call s:assert.equals(dein#load(plugins), 0)
  call s:assert.equals(g:dein#_plugins, plugins)

  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.load_invalid() "{{{
  call s:assert.equals(dein#load({}), 1)
endfunction"}}}

function! s:suite.load_ovewrite() "{{{
  let plugins1 = { 'foo': 'baz', 'bar': 'bar' }

  call s:assert.equals(dein#begin(), 0)

  call s:assert.equals(dein#load(plugins1), 0)

  let plugins2 = { 'foo': 'baz' }
  call s:assert.equals(dein#load(plugins2), 0)
  call s:assert.equals(g:dein#_plugins, extend(plugins1, plugins2))

  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.get() "{{{
  let plugins = { 'foo': { 'bar': 'baz' } }

  call dein#begin()
  call s:assert.equals(dein#load(plugins), 0)
  call s:assert.equals(dein#get(), plugins)
  call s:assert.equals(dein#get('foo'), { 'bar': 'baz' })
  call s:assert.equals(dein#get('baz'), {})
  call dein#end()
endfunction"}}}

" vim:foldmethod=marker:fen:
