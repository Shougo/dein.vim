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
  let s:is_windows = has('win32') || has('win64')
  let s:block_level = 0
  let s:prev_plugins = []

  let g:dein#_plugins = {}
  let g:dein#name = ''
  let g:dein#_base_path = ''
  let g:dein#_runtime_path = ''
  let g:dein#_off1 = ''
  let g:dein#_off2 = ''
  let g:dein#_vimrcs = []

  augroup dein
    autocmd!
    autocmd InsertEnter * call dein#autoload#_on_i()
    autocmd FileType * nested
          \ if &filetype != '' |
          \   call dein#autoload#_on_ft() |
          \ endif
    autocmd FuncUndefined * call s:on_func(expand('<afile>'))
    autocmd VimEnter * call dein#_call_hook('post_source')
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
function! dein#_get_base_path() abort "{{{
  return g:dein#_base_path
endfunction"}}}
function! dein#_get_runtime_path() abort "{{{
  if !isdirectory(g:dein#_runtime_path)
    call mkdir(g:dein#_runtime_path, 'p')
  endif

  return g:dein#_runtime_path
endfunction"}}}
function! dein#_get_tags_path() abort "{{{
  if g:dein#_runtime_path == '' || dein#util#_is_sudo()
    return ''
  endif

  let dir = g:dein#_runtime_path . '/doc'
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif
  return dir
endfunction"}}}

function! dein#begin(path) abort "{{{
  if has('vim_starting')
    call dein#_init()
  endif

  if a:path == '' || s:block_level != 0
    call dein#util#_error('Invalid begin/end block usage.')
    return 1
  endif

  let s:block_level += 1
  let g:dein#_base_path = dein#_expand(a:path)
  if g:dein#_base_path[-1:] == '/'
    let g:dein#_base_path = g:dein#_base_path[: -2]
  endif
  let g:dein#_runtime_path = g:dein#_base_path . '/.dein'

  call dein#_filetype_off()

  if !has('vim_starting')
    let s:prev_plugins = keys(filter(copy(g:dein#_plugins), 'v:val.merged'))
    execute 'set rtp-='.fnameescape(g:dein#_runtime_path)
    execute 'set rtp-='.fnameescape(g:dein#_runtime_path.'/after')
  endif

  " Join to the tail in runtimepath.
  let rtps = dein#_split_rtp(&runtimepath)
  let n = index(rtps, $VIMRUNTIME)
  if n < 0
    call dein#util#_error('Invalid runtimepath.')
    return 1
  endif
  let &runtimepath = dein#_join_rtp(
        \ add(insert(rtps, g:dein#_runtime_path, n-1),
        \     g:dein#_runtime_path.'/after'),
        \ &runtimepath, g:dein#_runtime_path)
endfunction"}}}

function! dein#end() abort "{{{
  if s:block_level != 1
    call dein#util#_error('Invalid begin/end block usage.')
    return 1
  endif

  let s:block_level -= 1

  " Add runtimepath
  let rtps = dein#_split_rtp(&runtimepath)
  let index = index(rtps, g:dein#_runtime_path)
  if index < 0
    call dein#util#_error('Invalid runtimepath.')
    return 1
  endif

  let sourced = []
  for plugin in filter(values(g:dein#_plugins),
        \ "!v:val.lazy && !v:val.sourced && v:val.rtp != ''")
    " Load dependencies
    if !empty(plugin.depends)
      if s:load_depends(plugin, rtps, index)
        return 1
      endif
      continue
    endif

    if !plugin.merged
      call insert(rtps, plugin.rtp, index)
      if isdirectory(plugin.rtp.'/after')
        call add(rtps, plugin.rtp.'/after')
      endif
    endif

    let plugin.sourced = 1
    call add(sourced, plugin)
  endfor
  let &runtimepath = dein#_join_rtp(rtps, &runtimepath, '')

  call dein#_call_hook('source', sourced)

  if !has('vim_starting')
    let merged_plugins = keys(filter(copy(g:dein#_plugins), 'v:val.merged'))
    if merged_plugins !=# s:prev_plugins
      call dein#install#_recache_runtimepath()
    endif
    call dein#_call_hook('post_source')
    call dein#autoload#_reset_ftplugin()
  endif
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
  let plugins = empty(a:000) ? copy(g:dein#_plugins)
        \ : map(dein#_convert2list(a:1), 'get(g:dein#_plugins, v:val, {})')
  return dein#autoload#_source(plugins)
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

function! dein#save_cache() abort "{{{
  return dein#util#_save_cache(g:dein#_vimrcs, 0)
endfunction"}}}
function! dein#load_cache(...) abort "{{{
  try
    let plugins = call('dein#load_cache_raw', a:000)
    if empty(plugins)
      return 1
    endif

    let g:dein#_plugins = plugins
    for plugin in filter(dein#_get_lazy_plugins(),
          \ '!empty(v:val.on_cmd) || !empty(v:val.on_map)')
      if !empty(plugin.on_cmd)
        call dein#_add_dummy_commands(plugin)
      endif
      if !empty(plugin.on_map)
        call dein#_add_dummy_mappings(plugin)
      endif
    endfor
  catch
    call dein#util#_error('Error occurred while loading cache : '
          \ . v:exception)
    call dein#clear_cache()
    return 1
  endtry
endfunction"}}}
function! dein#load_cache_raw(...) abort "{{{
  let g:dein#_vimrcs = a:0 ? a:1 : [$MYVIMRC]
  let starting = a:0 > 1 ? a:2 : has('vim_starting')

  let cache = dein#_get_cache_file()
  if !starting || !filereadable(cache) | return {} | endif

  if !empty(filter(map(copy(g:dein#_vimrcs), 'getftime(dein#_expand(v:val))'),
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
  return dein#_get_base_path() . '/cache_' . v:progname
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
  return dein#_get_base_path() . '/state_' . v:progname . '.vim'
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

" Helper functions
function! dein#_substitute_path(path) abort "{{{
  return (s:is_windows && a:path =~ '\\') ? tr(a:path, '\', '/') : a:path
endfunction"}}}
function! dein#_expand(path) abort "{{{
  let path = (a:path =~ '^\~') ? fnamemodify(a:path, ':p') :
        \ (a:path =~ '^\$\h\w*') ? substitute(a:path,
        \               '^\$\h\w*', '\=eval(submatch(0))', '') :
        \ a:path
  return (s:is_windows && path =~ '\\') ?
        \ dein#_substitute_path(path) : path
endfunction"}}}
function! dein#_split_rtp(runtimepath) abort "{{{
  if stridx(a:runtimepath, '\,') < 0
    return split(a:runtimepath, ',')
  endif

  let split = split(a:runtimepath, '\\\@<!\%(\\\\\)*\zs,')
  return map(split,'substitute(v:val, ''\\\([\\,]\)'', "\\1", "g")')
endfunction"}}}
function! dein#_join_rtp(list, runtimepath, rtp) abort "{{{
  return (stridx(a:runtimepath, '\,') < 0 && stridx(a:rtp, ',') < 0) ?
        \ join(a:list, ',') : join(map(copy(a:list), 's:escape(v:val)'), ',')
endfunction"}}}
function! dein#_convert2list(expr) abort "{{{
  return type(a:expr) ==# type([]) ? copy(a:expr) :
        \ type(a:expr) ==# type('') ?
        \   (a:expr == '' ? [] : split(a:expr, '\r\?\n', 1))
        \ : [a:expr]
endfunction"}}}
function! dein#_get_lazy_plugins() abort "{{{
  return filter(values(g:dein#_plugins), '!v:val.sourced')
endfunction"}}}
function! dein#_filetype_off() abort "{{{
  let filetype_out = dein#_redir('filetype')

  if filetype_out =~# 'plugin:ON'
        \ || filetype_out =~# 'indent:ON'
    let g:dein#_off1 = 'filetype plugin indent off'
    execute g:dein#_off1
  endif

  if filetype_out =~# 'detection:ON'
    let g:dein#_off2 = 'filetype off'
    execute g:dein#_off2
  endif

  return filetype_out
endfunction"}}}
function! dein#_call_hook(hook_name, ...) abort "{{{
  let prefix = '#User#dein#'.a:hook_name.'#'
  let plugins = filter(dein#_convert2list(
        \ (empty(a:000) ? dein#get() : a:1)),
        \ "get(v:val, 'sourced', 0) && exists(prefix . v:val.name)")

  for plugin in dein#_tsort(plugins)
    let autocmd = 'dein#' . a:hook_name . '#' . plugin.name
    if exists('#User#'.autocmd)
      execute 'doautocmd User' autocmd
    endif
  endfor
endfunction"}}}
function! dein#_tsort(plugins) abort "{{{
  let sorted = []
  let mark = {}
  for target in a:plugins
    call s:tsort_impl(target, mark, sorted)
  endfor

  return sorted
endfunction"}}}
function! dein#_add_dummy_commands(plugin) abort "{{{
  for command in a:plugin.dummy_commands
    silent! execute command[1]
  endfor
endfunction"}}}
function! s:generate_dummy_commands(plugin) abort "{{{
  for name in a:plugin.on_cmd
    " Define dummy commands.
    let raw_cmd = 'command '
          \ . '-complete=customlist,dein#autoload#_dummy_complete'
          \ . ' -bang -bar -range -nargs=* '. name
          \ . printf(" call dein#autoload#_on_cmd(%s, %s, <q-args>,
          \  expand('<bang>'), expand('<line1>'), expand('<line2>'))",
          \   string(name), string(a:plugin.name))

    call add(a:plugin.dummy_commands, [name, raw_cmd])
  endfor
endfunction"}}}
function! dein#_add_dummy_mappings(plugin) abort "{{{
  for mapping in a:plugin.dummy_mappings
    silent! execute mapping[2]
  endfor
endfunction"}}}

" Executes a command and returns its output.
" This wraps Vim's `:redir`, and makes sure that the `verbose` settings have
" no influence.
function! dein#_redir(cmd) abort "{{{
  let [save_verbose, save_verbosefile] = [&verbose, &verbosefile]
  set verbose=0 verbosefile=
  redir => res
  silent! execute a:cmd
  redir END
  let [&verbose, &verbosefile] = [save_verbose, save_verbosefile]
  return res
endfunction"}}}

" Escape a path for runtimepath.
function! s:escape(path) abort "{{{
  return substitute(a:path, ',\|\\,\@=', '\\\0', 'g')
endfunction"}}}

function! s:tsort_impl(target, mark, sorted) abort "{{{
  if empty(a:target) || has_key(a:mark, a:target.name)
    return
  endif

  let a:mark[a:target.name] = 1
  for depend in a:target.depends
    call s:tsort_impl(dein#get(depend), a:mark, a:sorted)
  endfor

  call add(a:sorted, a:target)
endfunction"}}}

function! s:on_func(name) abort "{{{
  let function_prefix = substitute(a:name, '[^#]*$', '', '')
  if function_prefix =~# '^dein#'
        \ || function_prefix ==# 'vital#'
        \ || has('vim_starting')
    return
  endif

  call dein#autoload#_on_func(a:name)
endfunction"}}}

function! s:load_depends(plugin, rtps, index) abort "{{{
  for name in a:plugin.depends
    if !has_key(g:dein#_plugins, name)
      call dein#util#_error(printf('Plugin name "%s" is not found.', name))
      return 1
    endif
  endfor

  for depend in dein#_tsort([a:plugin])
    if depend.sourced
      return
    endif

    let depend.sourced = 1

    if !depend.merged
      call insert(a:rtps, depend.rtp, a:index)
      if isdirectory(depend.rtp.'/after')
        call add(a:rtps, depend.rtp.'/after')
      endif
    endif
  endfor
endfunction"}}}

" vim: foldmethod=marker
