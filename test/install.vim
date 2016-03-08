" set verbose=1

let s:suite = themis#suite('install')
let s:assert = themis#helper('assert')

let s:path = fnamemodify('.cache', ':p') . '/'
let s:path2 = fnamemodify('.cache2', ':p') . '/'
let s:path3 = fnamemodify('.cache3', ':p') . '/'
let s:runtimepath_save = &runtimepath
let s:filetype_save = &l:filetype

let s:this_script = fnamemodify(expand('<sfile>'), ':p')

function! s:dein_install() abort
  return dein#install#_update([], 0, 0)
endfunction

function! s:dein_update() abort
  return dein#install#_update([], 1, 0)
endfunction

function! s:suite.before_each() abort "{{{
  call dein#_init()
  let &runtimepath = s:runtimepath_save
  let &l:filetype = s:filetype_save
  let g:temp = tempname()
  let g:dein#install_progress_type = 'echo'
endfunction"}}}

function! s:suite.install() abort "{{{
  let g:dein#install_progress_type = 'title'

  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call dein#end()

  call s:assert.equals(s:dein_install(), 0)

  let plugin = dein#get('neocomplete.vim')
  call s:assert.true(isdirectory(plugin.rtp))
endfunction"}}}

function! s:suite.tap() abort "{{{
  call dein#begin(s:path)
  call s:assert.equals(dein#tap('neocomplete.vim'), 0)
  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)
  call s:assert.equals(dein#add('Shougo/unite.vim', {'if':0}), 0)
  call s:assert.equals(s:dein_install(), 0)
  call s:assert.equals(dein#tap('neocomplete.vim'), 1)
  call s:assert.equals(dein#tap('unite.vim'), 0)
  call dein#end()
endfunction"}}}

function! s:suite.reinstall() abort "{{{
  let g:dein#install_progress_type = 'statusline'

  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  call s:assert.equals(dein#reinstall('neocomplete.vim'), 0)
endfunction"}}}

function! s:suite.update() abort "{{{
  let g:dein#install_progress_type = 'echo'

  call dein#begin(s:path2)

  call s:assert.equals(dein#add('Shougo/neopairs.vim', {'frozen': 1}), 0)

  " Travis Git does not support the feature.
  " call s:assert.equals(dein#add('Shougo/neobundle.vim',
  "       \ {'rev': 'release'}), 0)

  call s:assert.equals(s:dein_update(), 0)

  let plugin = dein#get('neopairs.vim')
  let plugin2 = dein#get('neobundle.vim')

  call s:assert.equals(plugin.rtp,
        \ s:path2.'repos/github.com/Shougo/neopairs.vim')

  call s:assert.true(isdirectory(plugin.rtp))

  call dein#end()

  " Latest neobundle release is 3.2
  " call s:assert.equals(s:get_revision(plugin2),
  "       \ '47576978549f16ef21784a6d15e6a5ae38ddb800')
endfunction"}}}

function! s:suite.check_install() abort "{{{
  let g:dein#install_progress_type = 'tabline'

  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call s:assert.equals(s:dein_install(), 0)

  call s:assert.false(dein#check_install())
  call s:assert.false(dein#check_install(['vimshell.vim']))
  call s:assert.false(dein#check_install(['neocomplete.vim']))

  call dein#end()
endfunction"}}}

function! s:suite.fetch() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim', { 'rtp': '' }), 0)

  call s:assert.equals(s:dein_install(), 0)

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(plugin.rtp, '')

  call dein#end()

  call s:assert.equals(plugin.sourced, 0)
endfunction"}}}

function! s:suite.reload() abort "{{{
  " 1st load
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  " 2nd load
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')
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

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call s:assert.equals(dein#source(['neocomplete.vim']), 0)

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_i() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'on_i': 1 }), 0)

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call dein#autoload#_on_i()

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_ft() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'on_ft': 'cpp' }), 0)

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  set filetype=c
  call dein#autoload#_on_ft()

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  set filetype=cpp
  call dein#autoload#_on_ft()

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_path() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'on_path': '.*' }), 0)

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  execut 'edit' tempname()

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_source() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neopairs.vim',
        \ { 'on_source': ['neocomplete.vim'] }), 0)
  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'lazy': 1 }), 0)

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('neopairs.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call dein#source('neocomplete.vim')

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_func() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/vimshell.vim',
        \ { 'lazy': 1 }), 0)
  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'on_func': 'neocomplete#initialize' }), 0)

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')
  let plugin2 = dein#get('vimshell.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin2.rtp')), 0)

  call dein#autoload#_on_func('neocomplete#initialize')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin2.rtp')), 0)

  call vimshell#version()

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin2.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_cmd() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'on_cmd': 'NeoCompleteDisable' }), 0)

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(plugin.pre_cmd, ['neocomplete'])
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  NeoCompleteDisable

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_map() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/unite.vim',
        \ { 'lazy': 1 }), 0)
  call s:assert.equals(dein#add('Shougo/vimfiler.vim',
        \ { 'on_map': '<Plug>', 'depends': 'unite.vim' }), 0)

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('vimfiler.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call dein#autoload#_on_map('', 'vimfiler.vim', 'n')

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.lazy_on_pre_cmd() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'lazy': 1 }), 0)

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(plugin.pre_cmd, ['neocomplete'])
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call dein#autoload#_on_pre_cmd('NeoCompleteDisable')

  call s:assert.equals(plugin.sourced, 1)

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
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
  call s:assert.equals(dein#add('Shougo/vimshell.vim', {'merged': 0}), 0)

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('vimshell.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.depends_lazy() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'depends': 'vimshell.vim', 'lazy': 1 }), 0)
  call s:assert.equals(dein#add('Shougo/vimshell.vim',
        \ { 'lazy': 1 }), 0)

  let plugin = dein#get('vimshell.vim')

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  call s:assert.equals(plugin.sourced, 0)
  call s:assert.equals(isdirectory(plugin.rtp), 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call s:assert.equals(dein#source(['neocomplete.vim']), 0)

  call s:assert.equals(plugin.sourced, 1)

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction"}}}

function! s:suite.depends_error() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'depends': 'vimfiler.vim'}), 0)

  call s:assert.equals(s:dein_install(), 0)

  call s:assert.equals(dein#end(), 1)
endfunction"}}}

function! s:suite.depends_error_lazy() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim',
        \ { 'depends': 'vimfiler.vim', 'lazy': 1 }), 0)

  call s:assert.equals(s:dein_install(), 0)

  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#source(['neocomplete.vim']), 1)
endfunction"}}}

function! s:suite.hooks() abort "{{{
  call dein#begin(s:path)

  call s:assert.equals(dein#add('Shougo/neocomplete.vim'), 0)

  let s:test = 0

  autocmd User dein#source#neocomplete.vim let s:test = 1

  call s:assert.equals(s:dein_install(), 0)

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

  call s:assert.equals(dein#add('Shougo/neopairs.vim', {'frozen': 1}), 0)
  call s:assert.equals(dein#get('neopairs.vim').orig_opts, {'frozen': 1})

  call dein#local(s:path2.'repos/github.com/Shougo/', {'timeout': 1})

  call s:assert.equals(dein#get('neopairs.vim').sourced, 0)
  call s:assert.equals(dein#get('neopairs.vim').timeout, 1)

  call s:assert.equals(dein#end(), 0)

  let plugin2 = dein#get('neopairs.vim')

  call s:assert.equals(plugin2.rtp,
        \ s:path2.'repos/github.com/Shougo/neopairs.vim')
endfunction"}}}

function! s:suite.local_nongit() abort "{{{
  let temp = tempname()
  call mkdir(temp.'/plugin', 'p')
  call dein#begin(s:path)

  call dein#local(temp, {}, ['plugin'])

  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#get('plugin').type, 'none')

  call s:assert.equals(s:dein_update(), 0)
endfunction"}}}

function! s:suite.build() abort "{{{
  call dein#begin(tempname())

  call dein#add('Shougo/vimproc.vim', {
        \ 'build': {
        \     'windows': 'tools\\update-dll-mingw',
        \     'cygwin': 'make -f make_cygwin.mak',
        \     'mac': 'make -f make_mac.mak',
        \     'linux': 'make',
        \     'unix': 'gmake',
        \    },
        \ })

  call dein#end()

  call s:assert.equals(s:dein_install(), 0)

  call vimproc#version()
  call s:assert.true(filereadable(g:vimproc#dll_path))
endfunction"}}}

function! s:get_revision(plugin) abort "{{{
  let cwd = getcwd()
  try
    execute 'lcd' fnameescape(a:plugin.path)

    let rev = substitute(system('git rev-parse HEAD'), '\n$', '', '')

    return (rev !~ '\s') ? rev : ''
  finally
    execute 'lcd' fnameescape(cwd)
  endtry
endfunction"}}}

" vim:foldmethod=marker:fen:
