" set verbose=1

let s:suite = themis#suite('install')
let s:assert = themis#helper('assert')

let s:path = fnamemodify('.cache', ':p') . '/'
let s:path2 = fnamemodify('.cache2', ':p') . '/'
let s:runtimepath_save = &runtimepath
let s:filetype_save = &l:filetype

function! s:suite.before_each() abort "{{{
  call dein#_init()
  let &runtimepath = s:runtimepath_save
  let &l:filetype = s:filetype_save
  let g:temp = tempname()
endfunction"}}}

function! s:suite.install() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call s:assert.equals(dein#install(), 0)

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(plugin.rtp,
        \ s:path.'repos/github.com/Shougo/neocomplete.vim')

  call s:assert.true(isdirectory(plugin.rtp))

  call dein#end()

  call s:assert.true(index(dein#_split_rtp(&runtimepath), plugin.rtp) >= 0)
endfunction"}}}

function! s:suite.update() abort "{{{
  call dein#begin(s:path2)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call s:assert.equals(dein#add('Shougo/neopairs.vim'), 0)

  call s:assert.equals(dein#update(), 0)

  let plugin = dein#get('neopairs.vim')

  call s:assert.equals(plugin.rtp,
        \ s:path2.'repos/github.com/Shougo/neopairs.vim')

  call s:assert.true(isdirectory(plugin.rtp))

  call dein#end()

  call s:assert.true(index(dein#_split_rtp(&runtimepath), plugin.rtp) >= 0)
endfunction"}}}

function! s:suite.check_install() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call s:assert.equals(dein#install(), 0)

  call s:assert.false(dein#check_install())
  call s:assert.false(dein#check_install(['vimshell.vim']))
  call s:assert.false(dein#check_install(['neocomplete.vim']))

  call dein#end()
endfunction"}}}

function! s:suite.fetch() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim', { 'rtp': '' }), 0)

  call s:assert.equals(dein#install(), 0)

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(plugin.rtp, '')

  call dein#end()

  call s:assert.true(index(dein#_split_rtp(&runtimepath), plugin.rtp) < 0)
endfunction"}}}

function! s:suite.reload() abort "{{{
  " 1st load
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call s:assert.equals(dein#install(), 0)

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

  call s:assert.equals(dein#install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call s:assert.equals(dein#source(['neocomplete.vim']), 0)

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_i() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'on_i': 1 }), 0)

  call s:assert.equals(dein#install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call dein#autoload#_on_i()

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_ft() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'on_ft': 'cpp' }), 0)

  call s:assert.equals(dein#install(), 0)

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

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_path() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'on_path': '.*' }), 0)

  call s:assert.equals(dein#install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  execut 'edit' tempname()

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_source() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neopairs.vim',
        \ { 'on_source': ['neocomplete.vim'] }), 0)
  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'lazy': 1 }), 0)

  call s:assert.equals(dein#install(), 0)

  call dein#end()

  let plugin = dein#get('neopairs.vim')

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call dein#source('neocomplete.vim')

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_func() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/vimshell.vim',
        \ { 'lazy': 1 }), 0)
  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'on_func': 'neocomplete#initialize' }), 0)

  call s:assert.equals(dein#install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')
  let plugin2 = dein#get('vimshell.vim')

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)
  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin2.rtp')), 0)

  call dein#autoload#_on_func('neocomplete#initialize')

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin2.rtp')), 0)

  call vimshell#version()

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin2.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_cmd() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'on_cmd': 'NeoCompleteDisable' }), 0)

  call s:assert.equals(dein#install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(plugin.pre_cmd, ['neocomplete'])
  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  NeoCompleteDisable

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_map() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/unite.vim',
        \ { 'lazy': 1 }), 0)
  call s:assert.equals(dein#add('Shougo/vimfiler.vim',
        \ { 'on_map': '<Plug>', 'depends': 'unite.vim' }), 0)

  call s:assert.equals(dein#install(), 0)

  call dein#end()

  let plugin = dein#get('vimfiler.vim')

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call dein#autoload#_on_map('', 'vimfiler.vim', 'n')

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_pre_cmd() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'lazy': 1 }), 0)

  call s:assert.equals(dein#install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(plugin.pre_cmd, ['neocomplete'])
  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call dein#autoload#_on_pre_cmd('NeoCompleteDisable')

  call s:assert.equals(plugin.sourced, 1)

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
        \ { 'depends': 'vimshell.vim' }), 0)
  call s:assert.equals(dein#add('Shougo/vimshell.vim'), 0)

  call s:assert.equals(dein#install(), 0)

  call dein#end()

  let plugin = dein#get('vimshell.vim')

  call s:assert.equals(
        \ len(filter(dein#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.depends_lazy() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'depends': 'vimshell.vim', 'lazy': 1 }), 0)
  call s:assert.equals(dein#add('Shougo/vimshell.vim',
        \ { 'lazy': 1 }), 0)

  let plugin = dein#get('vimshell.vim')

  call s:assert.equals(dein#install(), 0)

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

  call s:assert.equals(dein#install(), 0)

  call s:assert.equals(dein#end(), 1)
endfunction"}}}

function! s:suite.depends_error_lazy() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'depends': 'vimfiler.vim', 'lazy': 1 }), 0)

  call s:assert.equals(dein#install(), 0)

  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#source(['neocomplete.vim']), 1)
endfunction"}}}

function! s:suite.hooks() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  let s:test = 0

  autocmd User dein#source#neocomplete.vim let s:test = 1

  call s:assert.equals(dein#install(), 0)

  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(s:test, 1)
endfunction"}}}

function! s:suite.no_toml() abort "{{{
  call dein#begin(s:path)

  call writefile([
        \ 'foobar'
        \ ], g:temp)
  call s:assert.equals(dein#load_toml(g:temp, {}), 1)

  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.no_plugins() abort "{{{
  call dein#begin(s:path)

  call writefile([], g:temp)
  call s:assert.equals(dein#load_toml(g:temp), 1)

  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.no_repository() abort "{{{
  call dein#begin(s:path)

  call writefile([
        \ "[[plugins]]",
        \ "filetypes = 'all'",
        \ "[[plugins]]",
        \ "filetypes = 'all'"
        \ ], g:temp)
  call s:assert.equals(dein#load_toml(g:temp), 1)

  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.normal() abort "{{{
  call dein#begin(s:path)

  call writefile([
        \ "[[plugins]]",
        \ "repo = 'Shougo/neocomplete.vim'",
        \ "on_ft = 'all'",
        \ ], g:temp)
  call s:assert.equals(dein#load_toml(g:temp, {'frozen': 1}), 0)

  let plugin = dein#get('neocomplete.vim')
  call s:assert.equals(plugin.frozen, 1)
  call s:assert.equals(plugin.on_ft, ['all'])

  call s:assert.equals(dein#end(), 0)
endfunction"}}}

function! s:suite.local() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim', {'frozen': 1}), 0)
  call s:assert.equals(dein#get('neocomplete.vim').orig_opts, {'frozen': 1})

  call dein#local(s:path2.'repos/github.com/Shougo/', {'timeout': 1 })

  call s:assert.equals(dein#get('neocomplete.vim').sourced, 0)
  call s:assert.equals(dein#get('neopairs.vim').timeout, 1)
  call s:assert.equals(dein#get('neocomplete.vim').timeout, 1)

  call s:assert.equals(dein#end(), 0)

  let plugin = dein#get('neocomplete.vim')
  let plugin2 = dein#get('neopairs.vim')

  call s:assert.equals(plugin.rtp,
        \ s:path2.'repos/github.com/Shougo/neocomplete.vim')
  call s:assert.equals(plugin2.rtp,
        \ s:path2.'repos/github.com/Shougo/neopairs.vim')

  call s:assert.equals(plugin.frozen, 1)
endfunction"}}}

" vim:foldmethod=marker:fen:
