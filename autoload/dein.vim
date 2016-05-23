"=============================================================================
" FILE: dein.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

if v:version < 704
  call dein#util#_error('Does not work this version of Vim (' . v:version . ').')
  finish
endif

function! dein#_init() abort "{{{
  let g:dein#name = ''
  let g:dein#plugin = {}

  let g:dein#_plugins = {}
  let g:dein#_base_path = ''
  let g:dein#_runtime_path = ''
  let g:dein#_hook_add = ''
  let g:dein#_ftplugin = {}
  let g:dein#_off1 = ''
  let g:dein#_off2 = ''
  let g:dein#_vimrcs = []
  let g:dein#_block_level = 0
  let g:dein#_event_plugins = {}

  augroup dein
    autocmd!
    autocmd FuncUndefined * call dein#autoload#_on_func(expand('<afile>'))
  augroup END

  augroup dein-events
    autocmd!
  augroup END

  if exists('##CmdUndefined')
    autocmd dein CmdUndefined *
          \ call dein#autoload#_on_pre_cmd(expand('<afile>'))
  endif

  for event in [
        \ 'BufRead', 'BufNewFile', 'BufNew', 'VimEnter', 'FileType',
        \ ]
    execute 'autocmd dein' event '*'
          \ "if &filetype != '' || bufnr('$') != 1
          \  || expand('<afile>') != '' |
          \    call dein#autoload#_on_default_event(".string(event).") |
          \  endif"
  endfor
endfunction"}}}

function! dein#tap(name) abort "{{{
  if !has_key(g:dein#_plugins, a:name)
        \ || !isdirectory(g:dein#_plugins[a:name].path)
    return 0
  endif

  let g:dein#name = a:name
  let g:dein#plugin = g:dein#_plugins[a:name]
  return 1
endfunction"}}}
function! dein#is_sourced(name) abort "{{{
  return get(get(g:dein#_plugins, a:name, {}), 'sourced', 0)
endfunction"}}}

function! dein#save_cache() abort "{{{
  call dein#util#_error('dein#save_cache() is deprecated.')
  call dein#util#_error('Please use dein#save_state() instead.')
  return 1
endfunction"}}}
function! dein#load_cache(...) abort "{{{
  call dein#util#_error('dein#load_cache() is deprecated.')
  call dein#util#_error('Please use dein#load_state() instead.')
  return 1
endfunction"}}}
function! dein#load_cache_raw(...) abort "{{{
  if a:0 | let g:dein#_vimrcs = a:1 | endif
  let starting = a:0 > 1 ? a:2 : has('vim_starting')

  let cache = dein#_get_cache_file()
  if !starting || !filereadable(cache) | return [{}, {}] | endif

  let time = getftime(cache)
  if !empty(filter(map(copy(g:dein#_vimrcs),
        \ 'getftime(expand(v:val))'), 'time < v:val'))
    return [{}, {}]
  endif

  let list = readfile(cache)
  if len(list) != 3
        \ || string(g:dein#_vimrcs) !=# list[0]
    return [{}, {}]
  endif
  return [dein#_json2vim(list[1]), dein#_json2vim(list[2])]
endfunction"}}}
function! dein#_get_cache_file() abort "{{{
  return g:dein#_base_path.'/cache_'.fnamemodify(v:progname, ':r')
endfunction"}}}
function! dein#_vim2json(expr) abort "{{{
  return   (has('nvim') && exists('*json_encode')) ? json_encode(a:expr)
        \ : has('patch-7.4.1498') ? js_encode(a:expr) : string(a:expr)
endfunction "}}}
function! dein#_json2vim(expr) abort "{{{
  sandbox return (has('nvim') && exists('*json_encode') ? json_decode(a:expr)
        \ : has('patch-7.4.1498') ? js_decode(a:expr) : eval(a:expr))
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
    if v:exception !=# 'Cache loading error'
      call dein#util#_error('Error occurred while loading state : '
            \ . v:exception)
    endif
    call dein#clear_state()
    return 1
  endtry
endfunction"}}}
function! dein#save_state() abort "{{{
  return dein#util#_save_state(has('vim_starting'))
endfunction"}}}
function! dein#clear_state() abort "{{{
  return dein#util#_clear_state()
endfunction"}}}
function! dein#_get_state_file() abort "{{{
  return g:dein#_base_path.'/state_'.fnamemodify(v:progname, ':r').'.vim'
endfunction"}}}

function! dein#begin(path, ...) abort "{{{
  return dein#util#_begin(a:path, empty(a:000) ? [$MYVIMRC] : a:1)
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
function! dein#check_install(...) abort "{{{
  let plugins = filter(empty(a:000) ? values(dein#get()) :
        \ filter(map(copy(a:1), 'dein#get(v:val)'), '!empty(v:val)'),
        \     '!isdirectory(v:val.path)')
  if empty(plugins)
    return 0
  endif

  call dein#util#_notify('Not installed plugins: ' .
        \ string(map(plugins, 'v:val.name')))
  return 1
endfunction"}}}
function! dein#check_clean() abort "{{{
  return dein#util#_check_clean()
endfunction"}}}
function! dein#install(...) abort "{{{
  return dein#install#_update(get(a:000, 0, []),
        \ 'install', dein#install#_is_async())
endfunction"}}}
function! dein#update(...) abort "{{{
  return dein#install#_update(get(a:000, 0, []),
        \ 'update', dein#install#_is_async())
endfunction"}}}
function! dein#check_update(...) abort "{{{
  return dein#install#_update(get(a:000, 0, []),
        \ 'check_update', dein#install#_is_async())
endfunction"}}}
function! dein#direct_install(repo, ...) abort "{{{
  call dein#install#_direct_install(a:repo, (a:0 ? a:1 : {}))
endfunction"}}}
function! dein#get_direct_plugins_path() abort "{{{
  return g:dein#_base_path.'/direct_install.vim'
endfunction"}}}
function! dein#reinstall(plugins) abort "{{{
  call dein#install#_reinstall(a:plugins)
endfunction"}}}
function! dein#rollback(date, ...) abort "{{{
  call dein#install#_rollback(a:date, (a:0 ? a:1 : []))
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
function! dein#load_dict(dict, ...) abort "{{{
  return dein#parse#_load_dict(a:dict, get(a:000, 0, {}))
endfunction"}}}
function! dein#get_log() abort "{{{
  return join(dein#install#_get_log(), "\n")
endfunction"}}}
function! dein#get_updates_log() abort "{{{
  return join(dein#install#_get_updates_log(), "\n")
endfunction"}}}
function! dein#each(command, ...) abort "{{{
  return dein#install#_each(a:command, (a:0 ? a:1 : []))
endfunction"}}}
function! dein#plugins2toml(plugins) abort "{{{
  return dein#parse#_plugins2toml(a:plugins)
endfunction"}}}
function! dein#disable(names) abort "{{{
  return dein#util#_disable(a:names)
endfunction"}}}
function! dein#config(arg, ...) abort "{{{
  return type(a:arg) != type([]) ?
        \ dein#util#_config(a:arg, get(a:000, 0, {})) :
        \ map(copy(a:arg), 'dein#util#_config(v:val, a:1)')
endfunction"}}}
function! dein#set_hook(name, hook_name, hook) abort "{{{
  return dein#util#_set_hook(a:name, a:hook_name, a:hook)
endfunction"}}}

" vim: foldmethod=marker
