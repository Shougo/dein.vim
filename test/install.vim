" set verbose=1

let s:suite = themis#suite('install')
let s:assert = themis#helper('assert')

let s:path = fnamemodify('.cache', ':p')
if s:path !~ '/$'
  let s:path .= '/'
endif
let s:path2 = fnamemodify('.cache2', ':p')
if s:path2 !~ '/$'
  let s:path2 .= '/'
endif
let s:runtimepath_save = &runtimepath
let s:filetype_save = &l:filetype

let s:this_script = fnamemodify(expand('<sfile>'), ':p')

function! s:dein_install() abort
  return dein#install#_update([], 'install', 0)
endfunction

function! s:dein_update() abort
  return dein#install#_update([], 'update', 0)
endfunction

function! s:dein_check_update() abort
  return dein#install#_update([], 'check_update', 0)
endfunction

function! s:suite.before_each() abort
  call dein#_init()
  let &runtimepath = s:runtimepath_save
  let &l:filetype = s:filetype_save
  let g:temp = tempname()
  let g:dein#install_progress_type = 'echo'
  let g:dein#enable_notification = 0
endfunction

function! s:suite.install() abort
  let g:dein#install_progress_type = 'title'
  let g:dein#enable_notification = 1

  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim')

  call dein#end()

  call s:assert.equals(s:dein_install(), 0)

  let plugin = dein#get('neocomplete.vim')
  call s:assert.true(isdirectory(plugin.rtp))
  call s:assert.equals(dein#each('git gc'), 0)
endfunction

function! s:suite.tap() abort
  call dein#begin(s:path)
  call s:assert.equals(dein#tap('neocomplete.vim'), 0)
  call dein#add('Shougo/neocomplete.vim')
  call dein#add('Shougo/unite.vim', {'if':0})
  call s:assert.equals(s:dein_install(), 0)
  call s:assert.equals(dein#tap('neocomplete.vim'), 1)
  call s:assert.equals(dein#tap('unite.vim'), 0)
  call dein#end()
endfunction

function! s:suite.reinstall() abort
  let g:dein#install_progress_type = 'statusline'
  let g:dein#install_progress_type = 'none'

  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim')

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  call s:assert.equals(dein#reinstall('neocomplete.vim'), 0)
endfunction

function! s:suite.direct_install() abort
  let g:dein#install_progress_type = 'none'
  call dein#begin(s:path)
  call dein#end()

  call s:assert.equals(dein#direct_install('Shougo/neocomplete.vim'), 0)
  call s:assert.equals(dein#get('neocomplete.vim').sourced, 1)
endfunction

function! s:suite.update() abort
  let g:dein#install_progress_type = 'echo'

  call dein#begin(s:path2)

  call dein#add('Shougo/neopairs.vim', {'frozen': 1})

  " Travis Git does not support the feature.
  " call dein#add('Shougo/neobundle.vim', {'rev': '*'})

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
endfunction

function! s:suite.check_install() abort
  let g:dein#install_progress_type = 'tabline'

  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim')

  call s:assert.equals(s:dein_install(), 0)

  call s:assert.false(dein#check_install())
  call s:assert.equals(dein#check_install(['hoge']), -1)

  call dein#end()
endfunction

function! s:suite.fetch() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim', { 'rtp': '' })

  call s:assert.equals(s:dein_install(), 0)

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(plugin.rtp, '')

  call dein#end()

  call s:assert.equals(plugin.sourced, 0)
endfunction

function! s:suite.reload() abort
  " 1st load
  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim')

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  " 2nd load
  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim')

  call dein#end()

  let plugin = dein#get('neocomplete.vim')
endfunction

function! s:suite.if() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim', {'if': 0, 'on_cmd': 'FooBar'})

  call s:assert.equals(dein#get('neocomplete.vim'), {})
  call s:assert.false(exists(':FooBar'))

  call dein#end()

  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim', {'if': '1+1'})

  call s:assert.equals(dein#get('neocomplete.vim').if, 2)

  call dein#end()
endfunction

function! s:suite.lazy_manual() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim', { 'lazy': 1 })

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
endfunction

function! s:suite.lazy_on_i() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim', { 'on_i': 1 })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  call s:assert.equals(g:dein#_event_plugins,
        \ {'InsertEnter': ['neocomplete.vim']})

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  doautocmd InsertEnter

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction

function! s:suite.lazy_on_ft() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim', { 'on_ft': 'cpp' })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  set filetype=c

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  set filetype=cpp

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction

function! s:suite.lazy_on_path() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim', { 'on_path': '.*' })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  execute 'edit' tempname()

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction

function! s:suite.lazy_on_if() abort
  call dein#begin(s:path)

  let temp = tempname()
  call dein#add('Shougo/neosnippet.vim',
        \ { 'on_if': '&filetype ==# "foobar"' })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('neosnippet.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  set filetype=foobar

  call s:assert.equals(plugin.lazy, 1)
  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction

function! s:suite.lazy_on_source() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neopairs.vim',
        \ { 'on_source': ['neocomplete.vim'] })
  call dein#add('Shougo/neocomplete.vim', { 'lazy': 1 })

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
endfunction

function! s:suite.lazy_on_func() abort
  call dein#begin(s:path)

  call dein#add('Shougo/vimshell.vim', { 'lazy': 1 })
  call dein#add('Shougo/neocomplete.vim',
        \ { 'on_func': 'neocomplete#initialize' })

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
endfunction

function! s:suite.lazy_on_cmd() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim',
        \ { 'on_cmd': 'NeoCompleteDisable' })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  NeoCompleteDisable

  call s:assert.equals(plugin.sourced, 1)
endfunction

function! s:suite.lazy_on_map() abort
  call dein#begin(s:path)

  call dein#add('Shougo/unite.vim', { 'lazy': 1 })
  call dein#add('Shougo/vimfiler.vim',
        \ { 'on_map': [['n', '<Plug>']], 'depends': 'unite.vim' })
  call dein#add('Shougo/vimshell.vim', { 'on_map': {'n': '<Plug>'} })
  call dein#add('thinca/vim-ref', { 'on_map': '<Plug>' })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('vimfiler.vim')
  let plugin2 = dein#get('vimshell.vim')
  let plugin3 = dein#get('vim-ref')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call dein#autoload#_on_map('', 'vimfiler.vim', 'n')
  call dein#autoload#_on_map('', 'vimshell.vim', 'n')
  call dein#autoload#_on_map('', 'vim-ref', 'n')

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(plugin2.sourced, 1)
  call s:assert.equals(plugin3.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction

function! s:suite.lazy_on_pre_cmd() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim', { 'lazy': 1 })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('neocomplete.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  call dein#autoload#_on_pre_cmd('NeoCompleteDisable')

  call s:assert.equals(plugin.sourced, 1)

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction

function! s:suite.lazy_on_idle() abort
  call dein#begin(s:path)

  call dein#add('Shougo/vimfiler.vim', { 'on_idle': 1})

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  call s:assert.equals(g:dein#_event_plugins,
        \ {'CursorHold': ['vimfiler.vim'], 'FocusLost': ['vimfiler.vim']})

  let plugin = dein#get('vimfiler.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 0)

  doautocmd CursorHold

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction

function! s:suite.depends() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim', { 'depends': 'vimshell.vim' })
  call dein#add('Shougo/vimshell.vim', {'merged': 0})

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  let plugin = dein#get('vimshell.vim')

  call s:assert.equals(
        \ len(filter(dein#util#_split_rtp(&runtimepath),
        \     'v:val ==# plugin.rtp')), 1)
endfunction

function! s:suite.depends_lazy() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim',
        \ { 'depends': 'vimshell.vim', 'lazy': 1 })
  call dein#add('Shougo/vimshell.vim', { 'lazy': 1 })

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
endfunction

function! s:suite.depends_error_lazy() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neocomplete.vim',
        \ { 'depends': 'vimfiler.vim' })

  call s:assert.equals(s:dein_install(), 0)

  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#source(['neocomplete.vim']), 0)

  call dein#begin(s:path)

  call dein#add('Shougo/vimfiler.vim', { 'lazy': 1 })
  call dein#add('Shougo/neocomplete.vim',
        \ { 'depends': 'vimfiler.vim' })

  call s:assert.equals(s:dein_install(), 0)

  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#source(['neocomplete.vim']), 0)
endfunction

function! s:suite.hooks() abort
  call dein#begin(s:path)

  let g:dein#_hook_add = 'let g:foo = 0'

  function! Foo() abort
  endfunction
  call dein#add('Shougo/neocomplete.vim', {
        \ 'hook_source':
        \   join(['let g:foobar = 2'], "\n"),
        \ 'hook_post_source':
        \   join(['if 1', 'let g:bar = 3', 'endif'], "\n"),
        \ })
  call dein#add('Shougo/neosnippet.vim', {
        \ 'hook_add': function('Foo'),
        \ 'hook_post_source': function('Foo'),
        \ })
  call dein#set_hook('neosnippet.vim', 'hook_source', function('Foo'))
  call dein#set_hook('neocomplete.vim', 'hook_add', 'let g:foobar = 1')

  call s:assert.equals(g:foobar, 1)

  call s:assert.equals(s:dein_install(), 0)

  call s:assert.equals(dein#end(), 0)
  call s:assert.equals(g:foo, 0)

  call dein#call_hook('source')
  call s:assert.equals(g:foobar, 2)
  call dein#call_hook('post_source')
  call s:assert.equals(g:bar, 3)
endfunction

function! s:suite.no_toml() abort
  call dein#begin(s:path)

  call writefile([
        \ 'foobar'
        \ ], g:temp)
  call s:assert.equals(dein#load_toml(g:temp, {}), 1)

  call s:assert.equals(dein#end(), 0)
endfunction

function! s:suite.no_plugins() abort
  call dein#begin(s:path)

  call writefile([], g:temp)
  call s:assert.equals(dein#load_toml(g:temp), 0)

  call s:assert.equals(dein#end(), 0)
endfunction

function! s:suite.no_repository() abort
  call dein#begin(s:path)

  call writefile([
        \ "[[plugins]]",
        \ "filetypes = 'all'",
        \ "[[plugins]]",
        \ "filetypes = 'all'"
        \ ], g:temp)
  call s:assert.equals(dein#load_toml(g:temp), 1)

  call s:assert.equals(dein#end(), 0)
endfunction

function! s:suite.normal() abort
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
endfunction

function! s:suite.local() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neopairs.vim', {'frozen': 1})
  call dein#local(s:path2.'repos/github.com/Shougo/', {'timeout': 1})

  call s:assert.equals(dein#get('neopairs.vim').sourced, 0)
  call s:assert.equals(dein#get('neopairs.vim').timeout, 1)

  call s:assert.equals(dein#end(), 0)

  let plugin2 = dein#get('neopairs.vim')

  call s:assert.equals(plugin2.rtp,
        \ s:path2.'repos/github.com/Shougo/neopairs.vim')
endfunction

function! s:suite.clean() abort
  call dein#begin(s:path2)

  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#check_clean(),
        \ [s:path2.'repos/github.com/Shougo/neopairs.vim'])
endfunction

function! s:suite.local_nongit() abort
  let temp = tempname()
  call mkdir(temp.'/plugin', 'p')
  call dein#begin(s:path)

  call dein#local(temp, {}, ['plugin'])

  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#get('plugin').type, 'none')

  call s:assert.equals(s:dein_update(), 0)
endfunction

function! s:suite.build() abort
  call dein#begin(tempname())

  call dein#add('Shougo/vimproc.vim', {
        \ 'build': 'make',
        \ 'hook_add':
        \   'let g:foobar = 1',
        \ 'hook_post_update':
        \   'let g:foobar = 4',
        \ })

  call dein#end()

  call s:assert.equals(g:foobar, 1)

  call s:assert.true(dein#check_install())
  call s:assert.true(dein#check_install(['vimproc.vim']))

  call s:assert.equals(s:dein_install(), 0)
  call s:assert.equals(s:dein_check_update(), 0)

  call s:assert.equals(g:foobar, 4)

  call vimproc#version()
  call s:assert.true(filereadable(g:vimproc#dll_path))
endfunction

function! s:suite.rollback() abort
  call dein#begin(tempname())

  call dein#add('Shougo/neocomplete.vim')

  call dein#end()

  call s:assert.equals(s:dein_install(), 0)

  let plugin = dein#get('neocomplete.vim')

  let old_rev = s:get_revision(plugin)

  " Change the revision manually
  let new_rev = '623831d7ca5f9065ae08bada8078361e343d5970'
  let cwd = getcwd()
  try
    call dein#install#_cd(plugin.path)
    call system('git reset --hard ' . new_rev)
  finally
    call dein#install#_cd(cwd)
  endtry

  call s:assert.equals(s:get_revision(plugin), new_rev)

  call dein#rollback('', ['neocomplete.vim'])

  call s:assert.equals(s:get_revision(plugin), old_rev)
endfunction

function! s:suite.script_type() abort
  call dein#begin(s:path)

  call dein#add(
        \ 'https://github.com/bronzehedwick/impactjs-colorscheme',
        \ {'script_type' : 'colors'})

  call dein#add(
        \ 'https://raw.githubusercontent.com/Shougo/'
        \ . 'shougo-s-github/master/vim/colors/candy.vim',
        \ {'script_type' : 'colors'})
  call s:assert.equals(dein#get('candy.vim').type, 'raw')

  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(s:dein_update(), 0)

  call s:assert.true(filereadable(
        \ dein#get('impactjs-colorscheme').rtp . '/colors/impactjs.vim'))
  call s:assert.true(filereadable(
        \ dein#get('candy.vim').rtp . '/colors/candy.vim'))
endfunction

function! s:get_revision(plugin) abort
  let cwd = getcwd()
  try
    execute 'lcd' fnameescape(a:plugin.path)

    let rev = substitute(system('git rev-parse HEAD'), '\n$', '', '')

    return (rev !~ '\s') ? rev : ''
  finally
    execute 'lcd' fnameescape(cwd)
  endtry
endfunction

function! s:suite.ftplugin() abort
  let g:dein#_ftplugin = {
        \ '_': 'echo 5555',
        \ 'python': 'setlocal foldmethod=indent',
        \ }
  call dein#begin(tempname())
  call dein#add('Shougo/echodoc.vim')
  call dein#end()

  call dein#recache_runtimepath()

  let ftplugin = readfile(dein#util#_get_runtime_path() . '/ftplugin.vim')
  let after = readfile($VIMRUNTIME  . '/ftplugin.vim') + [
        \ 'autocmd filetypeplugin FileType * call s:AfterFTPlugin()',
        \ 'function! s:AfterFTPlugin()',
        \ ] + split(get(g:dein#_ftplugin, '_', ''), '\n')
        \ + ['endfunction']
  call s:assert.equals(ftplugin, after)

  let python = readfile(dein#util#_get_runtime_path()
        \ . '/after/ftplugin/python.vim')
  call s:assert.equals(python[-1], g:dein#_ftplugin['python'])
endfunction
