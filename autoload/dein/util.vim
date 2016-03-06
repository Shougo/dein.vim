"=============================================================================
" FILE: util.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

let s:is_windows = has('win32') || has('win64')

" Global options definition." "{{{
let g:dein#install_max_processes =
      \ get(g:, 'dein#install_max_processes', 8)
let g:dein#install_process_timeout =
      \ get(g:, 'dein#install_process_timeout', 120)
let g:dein#install_progress_type =
      \ get(g:, 'dein#install_progress_type', 'statusline')
"}}}

function! dein#util#_is_windows() abort "{{{
  return s:is_windows
endfunction"}}}
function! dein#util#_is_mac() abort "{{{
  return !s:is_windows && !has('win32unix')
      \ && (has('mac') || has('macunix') || has('gui_macvim') ||
      \   (!isdirectory('/proc') && executable('sw_vers')))
endfunction"}}}
function! dein#util#_is_cygwin() abort "{{{
  return has('win32unix')
endfunction"}}}

function! dein#util#_is_sudo() abort "{{{
  return $SUDO_USER != '' && $USER !=# $SUDO_USER
      \ && $HOME !=# expand('~'.$USER)
      \ && $HOME ==# expand('~'.$SUDO_USER)
endfunction"}}}

function! dein#util#_get_base_path() abort "{{{
  return g:dein#_base_path
endfunction"}}}
function! dein#util#_get_runtime_path() abort "{{{
  if !isdirectory(g:dein#_runtime_path)
    call mkdir(g:dein#_runtime_path, 'p')
  endif

  return g:dein#_runtime_path
endfunction"}}}
function! dein#util#_get_tags_path() abort "{{{
  if g:dein#_runtime_path == '' || dein#util#_is_sudo()
    return ''
  endif

  let dir = g:dein#_runtime_path . '/doc'
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif
  return dir
endfunction"}}}

function! dein#util#_error(msg) abort "{{{
  for mes in s:msg2list(a:msg)
    echohl WarningMsg | echomsg '[dein] ' . mes | echohl None
  endfor
endfunction"}}}

function! dein#util#_chomp(str) abort "{{{
  return a:str != '' && a:str[-1:] == '/' ? a:str[: -2] : a:str
endfunction"}}}

function! dein#util#_set_default(var, val, ...) abort "{{{
  if !exists(a:var) || type({a:var}) != type(a:val)
    let alternate_var = get(a:000, 0, '')

    let {a:var} = exists(alternate_var) ?
          \ {alternate_var} : a:val
  endif
endfunction"}}}

function! dein#util#_uniq(list, ...) abort "{{{
  let list = a:0 ? map(copy(a:list),
        \              printf('[v:val, %s]', a:1)) : copy(a:list)
  let i = 0
  let seen = {}
  while i < len(list)
    let key = string(a:0 ? list[i][1] : list[i])
    if has_key(seen, key)
      call remove(list, i)
    else
      let seen[key] = 1
      let i += 1
    endif
  endwhile
  return a:0 ? map(list, 'v:val[0]') : list
endfunction"}}}

function! dein#util#_has_vimproc() abort "{{{
  if !exists('*vimproc#version')
    try
      call vimproc#version()
    catch
    endtry
  endif

  return exists('*vimproc#version')
endfunction"}}}

function! dein#util#_check_lazy_plugins() abort "{{{
  let no_meaning_plugins = map(filter(dein#util#_get_lazy_plugins(),
        \   "!v:val.local && isdirectory(v:val.rtp)
        \    && !isdirectory(v:val.rtp . '/plugin')
        \    && !isdirectory(v:val.rtp . '/after/plugin')"),
        \   'v:val.name')
  echomsg 'No meaning lazy plugins: ' string(no_meaning_plugins)
  return len(no_meaning_plugins)
endfunction"}}}

function! dein#util#_writefile(path, list) abort "{{{
  if dein#util#_is_sudo() || !filewritable(dein#util#_get_base_path())
    return 1
  endif

  let path = dein#util#_get_base_path() . '/' . a:path
  let dir = fnamemodify(path, ':h')
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif

  return writefile(a:list, path)
endfunction"}}}

function! dein#util#_get_type(name) abort "{{{
  return get({'git': dein#types#git#define()}, a:name, {})
endfunction"}}}

function! dein#util#_load_cache(...) abort "{{{
  try
    let plugins = call('dein#load_cache_raw', a:000)
    if empty(plugins)
      return 1
    endif

    let g:dein#_plugins = plugins
    for plugin in filter(dein#util#_get_lazy_plugins(),
          \ '!empty(v:val.on_cmd) || !empty(v:val.on_map)')
      if !empty(plugin.on_cmd)
        call dein#util#_add_dummy_commands(plugin)
      endif
      if !empty(plugin.on_map)
        call dein#util#_add_dummy_mappings(plugin)
      endif
    endfor
  catch
    call dein#util#_error('Error occurred while loading cache : '
          \ . v:exception)
    call dein#clear_cache()
    return 1
  endtry
endfunction"}}}
function! dein#util#_save_cache(vimrcs, is_state) abort "{{{
  if dein#util#_get_base_path() == ''
    " Ignore
    return 1
  endif

  " Set function prefixes before save cache
  call dein#autoload#_set_function_prefixes(dein#util#_get_lazy_plugins())

  let plugins = deepcopy(dein#get())

  if !a:is_state
    for plugin in values(plugins)
      let plugin.sourced = 0
    endfor
  endif

  let json = has('patch-7.4.1498') ? js_encode(plugins) : string(plugins)

  if !isdirectory(g:dein#_base_path)
    call mkdir(g:dein#_base_path, 'p')
  endif

  call writefile([dein#_get_cache_version(),
        \ string(a:vimrcs), json],
        \ dein#_get_cache_file())
endfunction"}}}
function! dein#util#_clear_cache() abort "{{{
  let cache = dein#_get_cache_file()
  if !filereadable(cache)
    return
  endif

  call delete(cache)
endfunction"}}}

function! dein#util#_save_state() abort "{{{
  if dein#util#_get_base_path() == ''
    " Ignore
    return 1
  endif

  call dein#util#_save_cache(g:dein#_vimrcs, 1)

  " Version check

  let lines = [
        \ 'let plugins = dein#load_cache_raw('. string(g:dein#_vimrcs) .', 1)',
        \ "if empty(plugins) | throw 'Cache loading error' | endif",
        \ 'let g:dein#_plugins = plugins',
        \ 'let g:dein#_base_path = ' . string(g:dein#_base_path),
        \ 'let g:dein#_runtime_path = ' . string(g:dein#_runtime_path),
        \ 'let &runtimepath = ' . string(&runtimepath),
        \ ]

  if g:dein#_off1 != ''
    call add(lines, g:dein#_off1)
  endif
  if g:dein#_off2 != ''
    call add(lines, g:dein#_off2)
  endif

  " Add dummy mappings/commands
  for plugin in dein#util#_get_lazy_plugins()
    for command in plugin.dummy_commands
      call add(lines, 'silent! ' . command[1])
    endfor
    for mapping in plugin.dummy_mappings
      call add(lines, 'silent! ' . mapping[2])
    endfor
  endfor

  call writefile(lines, dein#_get_state_file())
endfunction"}}}
function! dein#util#_clear_state() abort "{{{
  let cache = dein#_get_state_file()
  if !filereadable(cache)
    return
  endif

  call delete(cache)
endfunction"}}}

function! dein#util#_begin(path) abort "{{{
  if has('vim_starting')
    call dein#_init()
  endif

  if a:path == '' || g:dein#_block_level != 0
    call dein#util#_error('Invalid begin/end block usage.')
    return 1
  endif

  let g:dein#_block_level += 1
  let g:dein#_base_path = dein#util#_expand(a:path)
  if g:dein#_base_path[-1:] == '/'
    let g:dein#_base_path = g:dein#_base_path[: -2]
  endif
  let g:dein#_runtime_path = g:dein#_base_path . '/.dein'

  call dein#util#_filetype_off()

  if !has('vim_starting')
    execute 'set rtp-='.fnameescape(g:dein#_runtime_path)
    execute 'set rtp-='.fnameescape(g:dein#_runtime_path.'/after')
  endif

  " Join to the tail in runtimepath.
  let rtps = dein#util#_split_rtp(&runtimepath)
  let n = index(rtps, $VIMRUNTIME)
  if n < 0
    call dein#util#_error('Invalid runtimepath.')
    return 1
  endif
  let &runtimepath = dein#util#_join_rtp(
        \ add(insert(rtps, g:dein#_runtime_path, n-1),
        \     g:dein#_runtime_path.'/after'),
        \ &runtimepath, g:dein#_runtime_path)
endfunction"}}}
function! dein#util#_end() abort "{{{
  if g:dein#_block_level != 1
    call dein#util#_error('Invalid begin/end block usage.')
    return 1
  endif

  let g:dein#_block_level -= 1

  " Add runtimepath
  let rtps = dein#util#_split_rtp(&runtimepath)
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
  let &runtimepath = dein#util#_join_rtp(rtps, &runtimepath, '')

  call dein#call_hook('source', sourced)

  if !has('vim_starting')
    call dein#call_hook('post_source')
    call dein#autoload#_reset_ftplugin()
  endif
endfunction"}}}

function! dein#util#_call_hook(hook_name, ...) abort "{{{
  let prefix = '#User#dein#'.a:hook_name.'#'
  let plugins = filter(dein#util#_convert2list(
        \ (empty(a:000) ? dein#get() : a:1)),
        \ "get(v:val, 'sourced', 0) && exists(prefix . v:val.name)")

  for plugin in dein#util#_tsort(plugins)
    let autocmd = 'dein#' . a:hook_name . '#' . plugin.name
    if exists('#User#'.autocmd)
      execute 'doautocmd User' autocmd
    endif
  endfor
endfunction"}}}

function! dein#util#_add_dummy_commands(plugin) abort "{{{
  for command in a:plugin.dummy_commands
    silent! execute command[1]
  endfor
endfunction"}}}
function! dein#util#_add_dummy_mappings(plugin) abort "{{{
  for mapping in a:plugin.dummy_mappings
    silent! execute mapping[2]
  endfor
endfunction"}}}

function! dein#util#_tsort(plugins) abort "{{{
  let sorted = []
  let mark = {}
  for target in a:plugins
    call s:tsort_impl(target, mark, sorted)
  endfor

  return sorted
endfunction"}}}

function! dein#util#_split_rtp(runtimepath) abort "{{{
  if stridx(a:runtimepath, '\,') < 0
    return split(a:runtimepath, ',')
  endif

  let split = split(a:runtimepath, '\\\@<!\%(\\\\\)*\zs,')
  return map(split,'substitute(v:val, ''\\\([\\,]\)'', "\\1", "g")')
endfunction"}}}
function! dein#util#_join_rtp(list, runtimepath, rtp) abort "{{{
  return (stridx(a:runtimepath, '\,') < 0 && stridx(a:rtp, ',') < 0) ?
        \ join(a:list, ',') : join(map(copy(a:list), 's:escape(v:val)'), ',')
endfunction"}}}

function! dein#util#_expand(path) abort "{{{
  let path = (a:path =~ '^\~') ? fnamemodify(a:path, ':p') :
        \ (a:path =~ '^\$\h\w*') ? substitute(a:path,
        \               '^\$\h\w*', '\=eval(submatch(0))', '') :
        \ a:path
  return (s:is_windows && path =~ '\\') ?
        \ dein#util#_substitute_path(path) : path
endfunction"}}}
function! dein#util#_substitute_path(path) abort "{{{
  return (s:is_windows && a:path =~ '\\') ? tr(a:path, '\', '/') : a:path
endfunction"}}}

function! dein#util#_convert2list(expr) abort "{{{
  return type(a:expr) ==# type([]) ? copy(a:expr) :
        \ type(a:expr) ==# type('') ?
        \   (a:expr == '' ? [] : split(a:expr, '\r\?\n', 1))
        \ : [a:expr]
endfunction"}}}

function! dein#util#_filetype_off() abort "{{{
  let filetype_out = dein#util#_redir('filetype')

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

function! dein#util#_redir(cmd) abort "{{{
  let [save_verbose, save_verbosefile] = [&verbose, &verbosefile]
  set verbose=0 verbosefile=
  redir => res
  silent! execute a:cmd
  redir END
  let [&verbose, &verbosefile] = [save_verbose, save_verbosefile]
  return res
endfunction"}}}

function! dein#util#_get_lazy_plugins() abort "{{{
  return filter(values(g:dein#_plugins), '!v:val.sourced')
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

function! s:msg2list(expr) abort "{{{
  return type(a:expr) ==# type([]) ? a:expr : split(a:expr, '\n')
endfunction"}}}

" Escape a path for runtimepath.
function! s:escape(path) abort "{{{
  return substitute(a:path, ',\|\\,\@=', '\\\0', 'g')
endfunction"}}}

function! s:load_depends(plugin, rtps, index) abort "{{{
  for name in a:plugin.depends
    if !has_key(g:dein#_plugins, name)
      call dein#util#_error(printf('Plugin name "%s" is not found.', name))
      return 1
    endif
  endfor

  for depend in dein#util#_tsort([a:plugin])
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
