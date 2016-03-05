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

function! dein#util#_error(msg) abort "{{{
  for mes in s:msg2list(a:msg)
    echohl WarningMsg | echomsg '[dein] ' . mes | echohl None
  endfor
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
  let no_meaning_plugins = map(filter(dein#_get_lazy_plugins(),
        \   "!v:val.local && isdirectory(v:val.rtp)
        \    && !isdirectory(v:val.rtp . '/plugin')
        \    && !isdirectory(v:val.rtp . '/after/plugin')"),
        \   'v:val.name')
  echomsg 'No meaning lazy plugins: ' string(no_meaning_plugins)
  return len(no_meaning_plugins)
endfunction"}}}

function! dein#util#_writefile(path, list) abort "{{{
  if dein#util#_is_sudo() || !filewritable(dein#_get_base_path())
    return 1
  endif

  let path = dein#_get_base_path() . '/' . a:path
  let dir = fnamemodify(path, ':h')
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif

  return writefile(a:list, path)
endfunction"}}}

function! dein#util#_get_type(name) abort "{{{
  return get({'git': dein#types#git#define()}, a:name, {})
endfunction"}}}

function! dein#util#_save_cache(vimrcs) abort "{{{
  if dein#_get_base_path() == ''
    " Ignore
    return 1
  endif

  " Set function prefixes before save cache
  call dein#autoload#_set_function_prefixes(dein#_get_lazy_plugins())

  let plugins = deepcopy(dein#get())
  for plugin in values(plugins)
    let plugin.sourced = 0
  endfor

  call writefile([dein#_get_cache_version(),
        \ string(a:vimrcs), string(plugins)],
        \ dein#_get_cache_file())
endfunction"}}}

function! s:msg2list(expr) abort "{{{
  return type(a:expr) ==# type([]) ? a:expr : split(a:expr, '\n')
endfunction"}}}

