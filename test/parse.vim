let s:suite = themis#suite('parse')
let s:assert = themis#helper('assert')

let s:path = 'dummy'

function! s:suite.before_each() abort "{{{
  call dein#_init()
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

  call dein#end()
endfunction"}}}

" vim:foldmethod=marker:fen:
