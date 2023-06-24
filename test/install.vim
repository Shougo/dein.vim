"set verbose=1

const s:suite = themis#suite('install')
const s:assert = themis#helper('assert')

let s:path = '.cache'->fnamemodify(':p')
if s:path !~ '/$'
  let s:path ..= '/'
endif
const s:runtimepath_save = &runtimepath
const s:filetype_save = &l:filetype

const s:this_script = '<sfile>'->expand()->fnamemodify(':p')


function! s:dein_install() abort
  return dein#install#_do([], 'install', 0)
endfunction

function! s:dein_update() abort
  return dein#install#_do([], 'update', 0)
endfunction

function! s:suite.before_each() abort
  call dein#min#_init()
  let &runtimepath = s:runtimepath_save
  let &l:filetype = s:filetype_save
  let g:temp = tempname()
  let g:dein#install_progress_type = 'echo'
  let g:dein#enable_notification = v:false
  let g:foo = 0
  let g:foobar = 0
  let g:foobaz = 0
endfunction

" NOTE: It must be checked in the first
function! s:suite.install() abort
  let g:dein#install_progress_type = 'title'
  let g:dein#enable_notification = v:true

  call dein#begin(s:path)

  call dein#add('Shougo/deoplete.nvim')
  call dein#add('Shougo/deol.nvim')
  call dein#add('Shougo/neosnippet.vim')
  call dein#add('Shougo/neopairs.vim')
  call dein#add('Shougo/defx.nvim')
  call dein#add('Shougo/denite.nvim')

  call dein#end()

  call s:assert.equals(s:dein_install(), 0)

  const plugin = dein#get('deoplete.nvim')
  call s:assert.true(plugin.rtp->isdirectory())
  call s:assert.equals(dein#each('git gc'), 0)
endfunction

function! s:suite.tap() abort
  call dein#begin(s:path)
  call s:assert.equals(dein#tap('deoplete.nvim'), 0)
  call dein#add('Shougo/deoplete.nvim')
  call dein#add('Shougo/denite.nvim', {'if': 0})
  call s:assert.equals(s:dein_install(), 0)
  call s:assert.equals(dein#tap('deoplete.nvim'), 1)
  call s:assert.equals(dein#tap('denite.nvim'), 0)
  call dein#end()
endfunction

function! s:suite.reinstall() abort
  let g:dein#install_progress_type = 'none'

  call dein#begin(s:path)

  call dein#add('Shougo/deoplete.nvim')

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  call s:assert.equals(dein#reinstall('deoplete.nvim'), 0)
endfunction

function! s:suite.direct_install() abort
  let g:dein#install_progress_type = 'none'
  call dein#begin(s:path)
  call dein#end()

  call s:assert.equals(dein#direct_install('Shougo/deoplete.nvim'), 0)
  call s:assert.equals(dein#get('deoplete.nvim').sourced, 1)
endfunction

function! s:suite.update() abort
  let g:dein#install_progress_type = 'echo'

  call dein#begin(s:path)

  call dein#add('Shougo/neopairs.vim', #{ frozen: 1 })

  call s:assert.equals(s:dein_update(), 0)

  const plugin = dein#get('neopairs.vim')
  const plugin2 = dein#get('neobundle.vim')

  call s:assert.equals(plugin.rtp,
        \ s:path.'repos/github.com/Shougo/neopairs.vim')

  call s:assert.true(isdirectory(plugin.rtp))

  call dein#end()
endfunction

function! s:suite.check_install() abort
  let g:dein#install_progress_type = 'tabline'

  call dein#begin(s:path)

  call dein#add('Shougo/deoplete.nvim')

  call s:assert.equals(s:dein_install(), 0)

  call s:assert.false(dein#check_install())
  call s:assert.equals(dein#check_install(['hoge']), -1)

  call dein#end()
endfunction

function! s:suite.fetch() abort
  call dein#begin(s:path)

  call dein#add('Shougo/deoplete.nvim', #{ rtp: '' })

  call s:assert.equals(s:dein_install(), 0)

  const plugin = dein#get('deoplete.nvim')

  call s:assert.equals(plugin.rtp, '')

  call dein#end()

  call s:assert.equals(plugin.sourced, 0)
endfunction

function! s:suite.reload() abort
  " 1st load
  call dein#begin(s:path)

  call dein#add('Shougo/deoplete.nvim')

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  " 2nd load
  call dein#begin(s:path)

  call dein#add('Shougo/deoplete.nvim')

  call dein#end()

  const plugin = dein#get('deoplete.nvim')
endfunction

function! s:suite.if() abort
  call dein#begin(s:path)

  call dein#add('Shougo/deoplete.nvim', #{ if: 0, on_cmd: 'FooBar' })
  call s:assert.equals(dein#get('deoplete.nvim').if, 0)

  call dein#end()
endfunction

function! s:suite.lazy_manual() abort
  call dein#begin(s:path)

  call dein#add('Shougo/deoplete.nvim', #{ lazy: 1 })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  const plugin = dein#get('deoplete.nvim')

  call s:assert.equals(
        \ dein#util#_split_rtp(&runtimepath)
        \ ->filter({ _, val -> val ==# plugin.rtp })->len(), 0)

  call s:assert.equals(dein#source(['deoplete.nvim'])->len(), 1)

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ dein#util#_split_rtp(&runtimepath)
        \ ->filter({ _, val -> val ==# plugin.rtp })->len(), 1)
endfunction

function! s:suite.lazy_on_ft() abort
  call dein#begin(s:path)

  call dein#add('Shougo/deoplete.nvim', #{ on_ft: 'cpp' })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  const plugin = dein#get('deoplete.nvim')

  call s:assert.equals(
        \ dein#util#_split_rtp(&runtimepath)
        \ ->filter({ _, val -> val ==# plugin.rtp })->len(), 0)

  set filetype=c

  call s:assert.equals(
        \ dein#util#_split_rtp(&runtimepath)
        \ ->filter({ _, val -> val ==# plugin.rtp })->len(), 0)

  set filetype=cpp

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ dein#util#_split_rtp(&runtimepath)
        \ ->filter({ _, val -> val ==# plugin.rtp })->len(), 1)
endfunction

function! s:suite.lazy_on_path() abort
  call dein#begin(s:path)

  call dein#add('Shougo/deol.nvim', #{ on_path: '.*' })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  const plugin = dein#get('deol.nvim')

  call s:assert.equals(
        \ dein#util#_split_rtp(&runtimepath)
        \ ->filter({ _, val -> val ==# plugin.rtp })->len(), 0)

  execute 'edit' tempname()

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(
        \ dein#util#_split_rtp(&runtimepath)
        \ ->filter({ _, val -> val ==# plugin.rtp })->len(), 1)
endfunction

function! s:suite.lazy_on_if() abort
  call dein#begin(s:path)

  const temp = tempname()
  call dein#add('Shougo/deol.nvim',
        \ #{ on_if: '&l:filetype ==# "foobar"' })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  const plugin = dein#get('deol.nvim')

  call s:assert.equals(
        \ dein#util#_split_rtp(&runtimepath)
        \ ->filter({ _, val -> val ==# plugin.rtp })->len(), 0)

  set filetype=foobar

  call s:assert.equals(plugin.lazy, 1)
  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(dein#util#_split_rtp(&runtimepath)
        \ ->filter({ _, val -> val ==# plugin.rtp })->len(), 1)
endfunction

function! s:suite.lazy_on_source() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neopairs.vim', #{ on_source: ['deol.nvim'] })
  call dein#add('Shougo/deol.nvim', #{ lazy: 1 })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  const plugin = dein#get('neopairs.vim')

  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin.rtp })->len(), 0)

  call dein#source('deol.nvim')

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin.rtp })->len(), 1)
endfunction

function! s:suite.lazy_on_func() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neosnippet.vim', #{ lazy: 1 })
  call dein#add('Shougo/deoplete.nvim', #{ on_func: 'deoplete#initialize' })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  const plugin = dein#get('deoplete.nvim')
  const plugin2 = dein#get('neosnippet.vim')

  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin.rtp })->len(), 0)
  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin2.rtp })->len(), 0)

  call dein#autoload#_on_func('deoplete#initialize')

  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin.rtp })->len(), 1)
  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin2.rtp })->len(), 0)

  call neosnippet#expandable()

  call s:assert.equals(plugin.sourced, 1)
  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin2.rtp })->len(), 1)
endfunction

function! s:suite.lazy_on_cmd() abort
  call dein#begin(s:path)

  call dein#add('Shougo/deoplete.nvim', #{ on_cmd: 'NeoCompleteDisable' })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  const plugin = dein#get('deoplete.nvim')

  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin.rtp })->len(), 0)

  NeoCompleteDisable

  call s:assert.equals(plugin.sourced, 1)
endfunction

function! s:suite.lazy_on_map() abort
  call dein#begin(s:path)

  call dein#add('Shougo/deol.nvim', #{ on_map: #{ n: '<Plug>' } })
  call dein#add('Shougo/neosnippet.vim', #{ on_map: #{ n: '<Plug>' } })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  const plugin1 = dein#get('deol.nvim')
  const plugin2 = dein#get('neosnippet.vim')

  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin1.rtp })->len(), 0)

  call dein#autoload#_on_map('', 'deol.nvim', 'n')
  call dein#autoload#_on_map('', 'neosnippet.vim', 'n')

  call s:assert.equals(plugin1.sourced, 1)
  call s:assert.equals(plugin2.sourced, 1)
  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin1.rtp })->len(), 1)
endfunction

function! s:suite.lazy_on_pre_cmd() abort
  call dein#begin(s:path)

  call dein#add('Shougo/deol.nvim', #{ lazy: 1 })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  const plugin = dein#get('deol.nvim')

  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin.rtp })->len(), 0)

  call dein#autoload#_on_pre_cmd('Deol')

  call s:assert.equals(plugin.sourced, 1)

  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin.rtp })->len(), 1)
endfunction

function! s:suite.depends() abort
  call dein#begin(s:path)

  call dein#add('Shougo/deoplete.nvim', #{ depends: 'deol.nvim' })
  call dein#add('Shougo/deol.nvim', #{ merged: 0 })

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  const plugin = dein#get('deol.nvim')

  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin.rtp })->len(), 1)
endfunction

function! s:suite.depends_lazy() abort
  call dein#begin(s:path)

  call dein#add('Shougo/deoplete.nvim',
        \ #{ depends: 'deol.nvim', lazy: 1 })
  call dein#add('Shougo/deol.nvim', #{ lazy: 1 })

  const plugin = dein#get('deol.nvim')

  call s:assert.equals(s:dein_install(), 0)

  call dein#end()

  call s:assert.equals(plugin.sourced, 0)
  call s:assert.equals(isdirectory(plugin.rtp), 1)
  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin.rtp })->len(), 0)

  call s:assert.equals(len(dein#source(['deoplete.nvim'])), 2)

  call s:assert.equals(plugin.sourced, 1)

  call s:assert.equals(dein#util#_split_rtp(&runtimepath)->filter(
        \     { _, val -> val ==# plugin.rtp })->len(), 1)
endfunction

function! s:suite.depends_error_lazy() abort
  call dein#begin(s:path)

  call dein#add('Shougo/deoplete.nvim',
        \ { 'depends': 'defx.nvim' })

  call s:assert.equals(s:dein_install(), 0)

  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#source(['deoplete.nvim'])->len(), 0)

  call dein#begin(s:path)

  call dein#add('Shougo/defx.nvim', #{ lazy: 1 })
  call dein#add('Shougo/deoplete.nvim',
        \ { 'depends': 'defx.nvim' })

  call s:assert.equals(s:dein_install(), 0)

  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#source(['deoplete.nvim'])->len(), 0)
endfunction

function! s:suite.hooks() abort
  call dein#begin(s:path)

  let g:dein#_hook_add = 'let g:foo = 0'

  function! Foo() abort
  endfunction
  call dein#add('Shougo/deoplete.nvim', {
        \ 'hook_source':
        \   ['let g:foobar = 2']->join("\n"),
        \ 'hook_post_source':
        \   ['if 1', 'let g:bar = 3', 'endif']->join("\n"),
        \ })
  call dein#add('Shougo/neosnippet.vim', {
        \ 'hook_add': function('Foo'),
        \ 'hook_post_source': function('Foo'),
        \ })
  call dein#set_hook('neosnippet.vim', 'hook_source', function('Foo'))
  call dein#set_hook(['deoplete.nvim'], 'hook_add', 'let g:foobar = 1')
  call dein#set_hook([], 'hook_add', 'let g:baz = 3')

  call s:assert.equals(g:foobar, 1)

  call s:assert.equals(s:dein_install(), 0)

  call s:assert.equals(dein#end(), 0)
  call s:assert.equals(g:foo, 0)

  call dein#call_hook('source')
  call s:assert.equals(g:foobar, 2)
  call dein#call_hook('post_source')
  call s:assert.equals(g:bar, 3)
  call s:assert.equals(g:baz, 3)
endfunction

function! s:suite.no_toml() abort
  call dein#begin(s:path)

  call writefile(['foobar'], g:temp)
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
        \ "repo = 'Shougo/deoplete.nvim'",
        \ "on_ft = 'all'",
        \ ], g:temp)
  call s:assert.equals(dein#load_toml(g:temp, #{ frozen: 1 }), 0)

  const plugin = dein#get('deoplete.nvim')
  call s:assert.equals(plugin.frozen, 1)
  call s:assert.equals(plugin.on_ft, ['all'])

  call s:assert.equals(dein#end(), 0)
endfunction

function! s:suite.local() abort
  call dein#begin(s:path)

  call dein#add('Shougo/neopairs.vim', #{ frozen: 1 })
  call dein#local(s:path.'repos/github.com/Shougo/', #{ timeout: 1 })

  call s:assert.equals(dein#get('neopairs.vim').sourced, 0)
  call s:assert.equals(dein#get('neopairs.vim').timeout, 1)

  call s:assert.equals(dein#end(), 0)

  const plugin2 = dein#get('neopairs.vim')

  call s:assert.equals(plugin2.rtp,
        \ s:path.'repos/github.com/Shougo/neopairs.vim')
endfunction

function! s:suite.clean() abort
  call dein#begin(s:path)

  call s:assert.equals(dein#end(), 0)

  call s:assert.true(!empty(dein#check_clean()))
endfunction

function! s:suite.local_nongit() abort
  const temp = tempname()
  call mkdir(temp.'/plugin', 'p')
  call dein#begin(s:path)

  call dein#local(temp, {}, ['plugin'])

  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(dein#get('plugin').type, 'none')

  call s:assert.equals(s:dein_update(), 0)
endfunction

function! s:suite.build() abort
  call dein#begin(tempname())

  call dein#add('Shougo/vimproc.vim', #{
        \   build: 'make',
        \ })

  call dein#end()

  call s:assert.true(dein#check_install())
  call s:assert.true(dein#check_install(['vimproc.vim']))

  call s:assert.equals(s:dein_install(), 0)

  call vimproc#version()
  call s:assert.true(filereadable(g:vimproc#dll_path))
endfunction

function! s:suite.hook_update() abort
  call dein#begin(tempname())

  call dein#add('Shougo/ddu.vim', #{
        \   hook_post_update: 'let g:foobar = 4',
        \   hook_done_update: 'let g:foo = 1',
        \ })

  call dein#add('Shougo/ddc.vim', #{
        \   depends: 'ddu.vim',
        \   hook_depends_update: 'let g:foobaz = 3',
        \ })

  call dein#end()

  call s:assert.not_equals(g:foo, 1)
  call s:assert.not_equals(g:foobar, 4)
  call s:assert.not_equals(g:foobaz, 3)

  call s:assert.true(dein#check_install())
  call s:assert.true(dein#check_install(['ddu.vim']))

  call s:assert.equals(s:dein_install(), 0)

  call s:assert.equals(g:foo, 1)
  call s:assert.equals(g:foobar, 4)
  call s:assert.equals(g:foobaz, 3)
endfunction

function! s:suite.rollback() abort
  call dein#begin(tempname())

  call dein#add('Shougo/deoplete.nvim')

  call dein#end()

  call s:assert.equals(s:dein_install(), 0)

  const plugin = dein#get('deoplete.nvim')

  const old_rev = s:get_revision(plugin)

  " Change the revision manually
  const new_rev = 'bc7e8124d9c412fb3b0a6112baabde75a854d7b5'
  const cwd = getcwd()
  try
    call dein#install#_cd(plugin.path)
    call system('git reset --hard ' .. new_rev)
  finally
    call dein#install#_cd(cwd)
  endtry

  call s:assert.equals(s:get_revision(plugin), new_rev)

  call dein#rollback('', ['deoplete.nvim'])

  call s:assert.equals(s:get_revision(plugin), old_rev)
endfunction

function! s:suite.script_type() abort
  call dein#begin(s:path)

  call dein#add(
        \ 'https://github.com/bronzehedwick/impactjs-colorscheme',
        \ #{ script_type : 'colors' })

  call dein#add(
        \ 'https://raw.githubusercontent.com/Shougo/'
        \ .. 'shougo-s-github/master/vim/colors/candy.vim',
        \ #{ script_type : 'colors' })
  call s:assert.equals(dein#get('candy.vim').type, 'raw')

  call s:assert.equals(dein#end(), 0)

  call s:assert.equals(s:dein_update(), 0)

  call s:assert.true(
        \ (dein#get('impactjs-colorscheme').rtp .. '/colors/impactjs.vim')
        \ ->filereadable())
  call s:assert.true(
        \ (dein#get('candy.vim').rtp .. '/colors/candy.vim') ->filereadable())
endfunction

function! s:get_revision(plugin) abort
  const cwd = getcwd()
  try
    execute 'lcd' a:plugin.path->fnameescape()

    const rev = 'git rev-parse HEAD'->system()->substitute('\n$', '', '')

    return (rev !~ '\s') ? rev : ''
  finally
    execute 'lcd' cwd->fnameescape()
  endtry
endfunction

function! s:suite.ftplugin() abort
  call dein#begin(tempname())

  let g:dein#ftplugin = #{
        \   _: 'echo 5555',
        \   python: 'setlocal foldmethod=indent',
        \ }

  call dein#add('Shougo/echodoc.vim')
  call dein#end()

  call dein#recache_runtimepath()

  call s:assert.equals(
        \ readfile(dein#util#_get_runtime_path() .. '/after/ftplugin.vim'),
        \ dein#install#_get_default_ftplugin() + [
        \ 'function! s:after_ftplugin()',
        \ ] + g:dein#ftplugin->get('_', [])->split('\n') + ['endfunction'])

  const python =
        \ (dein#util#_get_runtime_path() .. '/after/ftplugin/python.vim')
        \ ->readfile()
  call s:assert.equals(python[-1], g:dein#ftplugin['python'])
  call s:assert.false(
        \ (dein#util#_get_runtime_path() .. '/after/ftplugin/_.vim')
        \ ->filereadable())
endfunction
