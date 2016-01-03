let s:suite = themis#suite('parse')
let s:assert = themis#helper('assert')

let s:path = '.cache'

function! s:suite.before_each() abort "{{{
  call dein#_init()
endfunction"}}}

function! s:suite.install() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call s:assert.equals(dein#update(), 0)

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(plugin.rtp,
        \ s:path.'/repos/github.com/Shougo/neocomplete.vim.git')

  call s:assert.true(isdirectory(plugin.rtp))

  call dein#end()

  call s:assert.true(index(dein#_split_rtp(&runtimepath), plugin.rtp) >= 0)
endfunction"}}}

function! s:suite.fetch() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim', { 'rtp': '' }), 0)

  call s:assert.equals(dein#update(), 0)

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(plugin.rtp, '')

  call dein#end()

  call s:assert.true(index(dein#_split_rtp(&runtimepath), plugin.rtp) < 0)
endfunction"}}}

" vim:foldmethod=marker:fen:
