" set verbose=1

let s:suite = themis#suite('state')
let s:assert = themis#helper('assert')

let s:runtimepath_save = &runtimepath
let s:path = fnamemodify('.cache', ':p') . '/'
let s:filetype_save = &l:filetype

function! s:suite.before_each() abort "{{{
  call dein#_init()
  let &runtimepath = s:runtimepath_save
  let &l:filetype = s:filetype_save
  let g:temp = tempname()
  let g:dein#install_progress_type = 'echo'
endfunction"}}}

function! s:suite.state() abort "{{{
  call s:assert.equals(dein#load_cache([$MYVIMRC], 0), 1)

  call delete(dein#_get_state_file())
  call s:assert.equals(dein#load_cache([$MYVIMRC], 1), 1)

  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim')
  call s:assert.equals(dein#end(), 0)

  let plugins = deepcopy(g:dein#_plugins)

  call s:assert.equals(dein#util#_save_state(1), 0)

  let runtimepath = &runtimepath

  let &runtimepath = s:runtimepath_save

  call s:assert.equals(dein#load_state(s:path, 1), 0)

  "call s:assert.equals(&runtimepath, runtimepath)
  "call s:assert.equals(dein#_plugins, plugins)
endfunction"}}}

function! s:suite.state_error() abort "{{{
  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim')
  call s:assert.equals(dein#save_state(), 1)
endfunction"}}}

" vim:foldmethod=marker:fen:
