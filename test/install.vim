let s:suite = themis#suite('parse')
let s:assert = themis#helper('assert')

let s:path = '.cache'
let s:runtimepath_save = &runtimepath

function! s:suite.before_each() abort "{{{
  call dein#_init()
  let &runtimepath = s:runtimepath_save
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

function! s:suite.check_install() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call s:assert.equals(dein#update(), 0)

  call s:assert.equals(dein#add('Shougo/vimshell.vim'), 0)

  call s:assert.true(dein#check_install())
  call s:assert.true(dein#check_install(['vimshell.vim']))
  call s:assert.false(dein#check_install(['neocomplete.vim']))

  call dein#end()
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

function! s:suite.reload() abort "{{{
  " 1st load
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call s:assert.equals(dein#update(), 0)

  call dein#end()

  " 2nd load
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_manual() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim', { 'lazy': 1 }), 0)

  call s:assert.equals(dein#update(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call s:assert.equals(dein#source(['neocomplete.vim']), 0)

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

" vim:foldmethod=marker:fen:
