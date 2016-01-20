" set verbose=1

let s:suite = themis#suite('install')
let s:assert = themis#helper('assert')

let s:path = '.cache'
let s:runtimepath_save = &runtimepath
let s:filetype_save = &l:filetype

function! s:suite.before_each() abort "{{{
  call dein#_init()
  let &runtimepath = s:runtimepath_save
  let &l:filetype = s:filetype_save
endfunction"}}}

function! s:suite.install() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call s:assert.equals(dein#update(), 0)

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(plugin.rtp,
        \ s:path.'/repos/github.com/Shougo/neocomplete.vim')

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

function! s:suite.if() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ {'if': 0}), 0)

  call s:assert.equals(dein#get('neocomplete.vim'), {})

  call dein#end()

  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ {'if': '1+1'}), 0)

  call s:assert.equals(dein#get('neocomplete.vim').if, 2)

  call dein#end()
endfunction"}}}

function! s:suite.lazy_manual() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'lazy': 1 }), 0)

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

function! s:suite.lazy_on_i() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'on_i': 1 }), 0)

  call s:assert.equals(dein#update(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call dein#autoload#_on_i()

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_ft() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'on_ft': 'cpp' }), 0)

  call s:assert.equals(dein#update(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  set filetype=c
  call dein#autoload#_on_ft()

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  set filetype=cpp
  call dein#autoload#_on_ft()

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.invalide_runtimepath() abort "{{{
  let &runtimepath = ''
  call s:assert.equals(dein#begin(s:path), 1)

  call s:suite.before_each()

  call s:assert.equals(dein#begin(s:path), 0)
  let &runtimepath = ''
  call s:assert.equals(dein#end(), 1)
endfunction"}}}

function! s:suite.depends() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'depends': 'vimproc.vim' }), 0)
  call s:assert.equals(dein#add('Shougo/vimproc.vim'), 0)

  call s:assert.equals(dein#update(), 0)

  call dein#end()

  let plugin = dein#get('vimproc.vim')

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.depends_lazy() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'depends': 'vimproc.vim', 'lazy': 1 }), 0)
  call s:assert.equals(dein#add('Shougo/vimproc.vim', {'lazy': 1}), 0)

  let plugin = dein#get('vimproc.vim')

  call s:assert.equals(dein#update(), 0)

  call dein#end()

  call s:assert.equals(plugin.sourced, 0)
  call s:assert.equals(isdirectory(plugin.rtp), 1)
  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call s:assert.equals(dein#source(['neocomplete.vim']), 0)

  call s:assert.equals(plugin.sourced, 1)

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.depends_error() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'depends': 'vimfiler.vim'}), 0)

  call s:assert.equals(dein#update(), 0)

  call s:assert.equals(dein#end(), 1)
endfunction"}}}

function! s:suite.depends_error_lazy() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'depends': 'vimfiler.vim', 'lazy': 1 }), 0)

  call s:assert.equals(dein#update(), 0)

  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#source(['neocomplete.vim']), 1)
endfunction"}}}

" vim:foldmethod=marker:fen:
