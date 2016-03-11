"=============================================================================
" FILE: dein.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

if v:version < 704
  call dein#util#_error('Does not work this version of Vim (' . v:version . ').')
  finish
endif

let s:parser_vim_path = fnamemodify(expand('<sfile>'), ':h')
      \ . '/dein/parser.vim'

function! dein#_init() abort "{{{
  let g:dein#_plugins = {}
  let g:dein#name = ''
  let g:dein#_base_path = ''
  let g:dein#_runtime_path = ''
  let g:dein#_off1 = ''
  let g:dein#_off2 = ''
  let g:dein#_vimrcs = []
  let g:dein#_block_level = 0

  augroup dein
    autocmd!
    autocmd InsertEnter * call dein#autoload#_on_i()
    autocmd FileType * nested
          \ if &filetype != '' |
          \   call dein#autoload#_on_ft() |
          \ endif
    autocmd FuncUndefined * call dein#autoload#_on_func(expand('<afile>'))
  augroup END

  if exists('##CmdUndefined')
    autocmd CmdUndefined *
          \ call dein#autoload#_on_pre_cmd(expand('<afile>'))
  endif

  for event in [
        \ 'BufRead', 'BufCreate', 'BufEnter',
        \ 'BufWinEnter', 'BufNew', 'VimEnter'
        \ ]
    execute 'autocmd dein' event '*'
          \ "if expand('<afile>') != '' |
          \   call dein#autoload#_on_path(expand('<afile>'), "
          \                           .string(event) . ") |
          \ endif"
  endfor
endfunction"}}}

function! dein#tap(name) abort "{{{
  if !has_key(g:dein#_plugins, a:name)
        \ || !isdirectory(g:dein#_plugins[a:name].path)
    return 0
  endif

  let g:dein#name = a:name
  return 1
endfunction"}}}
function! dein#is_sourced(name) abort "{{{
  return get(get(g:dein#_plugins, a:name, {}), 'sourced', 0)
endfunction"}}}
function! dein#check_install(...) abort "{{{
  let plugins = filter(empty(a:000) ? dein#get() : filter(map(copy(a:1),
        \                     'dein#get(v:val)'), '!empty(v:val)'),
        \     '!isdirectory(v:val.path)')
  if empty(plugins)
    return 0
  endif

  call dein#util#_error('Not installed plugins: ' .
        \ string(map(copy(plugins), 'v:val.name')))
  return 1
endfunction"}}}
function! dein#check_clean() abort "{{{
  return dein#util#_check_clean()
endfunction"}}}

function! dein#save_cache() abort "{{{
  return dein#util#_save_cache(g:dein#_vimrcs, 0)
endfunction"}}}
function! dein#load_cache(...) abort "{{{
  return call('dein#util#_load_cache', a:000)
endfunction"}}}
function! dein#load_cache_raw(...) abort "{{{
  let g:dein#_vimrcs = a:0 ? a:1 : [$MYVIMRC]
  let starting = a:0 > 1 ? a:2 : has('vim_starting')

  let cache = dein#_get_cache_file()
  if !starting || !filereadable(cache) | return {} | endif

  if !empty(filter(map(copy(g:dein#_vimrcs), 'getftime(expand(v:val))'),
        \ 'getftime(cache) < v:val'))
    return {}
  endif

  let list = readfile(cache)
  if len(list) != 3
        \ || list[0] !=# dein#_get_cache_version()
        \ || string(g:dein#_vimrcs) !=# list[1]
    call dein#clear_cache()
    return {}
  endif

  sandbox let plugins = has('patch-7.4.1498') ?
        \ js_decode(list[2]) : eval(list[2])

  if type(plugins) != type({})
    call dein#clear_cache()
    return {}
  endif

  return plugins
endfunction"}}}
function! dein#clear_cache() abort "{{{
  return dein#util#_clear_cache()
endfunction"}}}
function! dein#_get_cache_file() abort "{{{
  return g:dein#_base_path . '/cache_' . v:progname
endfunction"}}}
function! dein#_get_cache_version() abort "{{{
  return getftime(s:parser_vim_path)
endfunction "}}}

function! dein#load_state(path, ...) abort "{{{
  let starting = a:0 > 0 ? a:1 : has('vim_starting')

  if !starting
    return 1
  endif

  call dein#_init()

  let g:dein#_base_path = expand(a:path)

  let state = dein#_get_state_file()
  if !filereadable(state)
    return 1
  endif

  try
    execute 'source' fnameescape(state)
  catch
    call dein#util#_error('Error occurred while loading state : '
          \ . v:exception)
    call dein#clear_state()
    return 1
  endtry
endfunction"}}}
function! dein#save_state() abort "{{{
  return dein#util#_save_state()
endfunction"}}}
function! dein#clear_state() abort "{{{
  return dein#util#_clear_state()
endfunction"}}}
function! dein#_get_state_file() abort "{{{
  return g:dein#_base_path . '/state_' . v:progname . '.vim'
endfunction"}}}

function! dein#begin(path) abort "{{{
  return dein#util#_begin(a:path)
endfunction"}}}
function! dein#end() abort "{{{
  return dein#util#_end()
endfunction"}}}
function! dein#add(repo, ...) abort "{{{
  return dein#parse#_add(a:repo, get(a:000, 0, {}))
endfunction"}}}
function! dein#local(dir, ...) abort "{{{
  return dein#parse#_local(a:dir, get(a:000, 0, {}), get(a:000, 1, ['*']))
endfunction"}}}
function! dein#get(...) abort "{{{
  return empty(a:000) ? copy(g:dein#_plugins) : get(g:dein#_plugins, a:1, {})
endfunction"}}}
function! dein#source(...) abort "{{{
  return call('dein#autoload#_source', a:000)
endfunction"}}}
function! dein#install(...) abort "{{{
  return dein#install#_update(get(a:000, 0, []), 0, dein#install#_is_async())
endfunction"}}}
function! dein#update(...) abort "{{{
  return dein#install#_update(get(a:000, 0, []), 1, dein#install#_is_async())
endfunction"}}}
function! dein#reinstall(plugins) abort "{{{
  call dein#install#_reinstall(a:plugins)
endfunction"}}}
function! dein#remote_plugins() abort "{{{
  return dein#install#_remote_plugins()
endfunction"}}}
function! dein#recache_runtimepath() abort "{{{
  call dein#install#_recache_runtimepath()
endfunction"}}}
function! dein#call_hook(hook_name, ...) abort "{{{
  return call('dein#util#_call_hook', [a:hook_name] + a:000)
endfunction"}}}
function! dein#check_lazy_plugins() abort "{{{
  return dein#util#_check_lazy_plugins()
endfunction"}}}
function! dein#load_toml(filename, ...) abort "{{{
  return dein#parse#_load_toml(a:filename, get(a:000, 0, {}))
endfunction"}}}
function! dein#get_log() abort "{{{
  return join(dein#install#_get_log(), "\n")
endfunction"}}}
function! dein#get_updates_log() abort "{{{
  return join(dein#install#_get_updates_log(), "\n")
endfunction"}}}

" vim: foldmethod=marker
