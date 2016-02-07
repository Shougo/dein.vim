"=============================================================================
" FILE: dein.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

function! dein#_msg2list(expr) abort "{{{
  return type(a:expr) ==# type([]) ? a:expr : split(a:expr, '\n')
endfunction"}}}

function! dein#_error(msg) abort "{{{
  for mes in dein#_msg2list(a:msg)
    echohl WarningMsg | echomsg '[dein] ' . mes | echohl None
  endfor
endfunction"}}}

if v:version < 704
  call dein#_error('Does not work this version of Vim (' . v:version . ').')
  finish
endif

let s:is_windows = has('win32') || has('win64')

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
function! dein#_set_default(var, val, ...) abort "{{{
  if !exists(a:var) || type({a:var}) != type(a:val)
    let alternate_var = get(a:000, 0, '')

    let {a:var} = exists(alternate_var) ?
          \ {alternate_var} : a:val
  endif
endfunction"}}}

" Global options definition." "{{{
"}}}

function! dein#_init() abort "{{{
  let s:base_path = ''
  let s:block_level = 0
  let g:dein#_plugins = {}

  augroup dein
    autocmd!
    autocmd InsertEnter * call dein#autoload#_on_i()
    autocmd FileType * call dein#autoload#_on_ft()
    autocmd FileType * call dein#autoload#_on_ft()
  augroup END

  for event in [
        \ 'BufRead', 'BufCreate', 'BufEnter',
        \ 'BufWinEnter', 'BufNew', 'VimEnter'
        \ ]
    execute 'autocmd dein' event
          \ "* call dein#autoload#_on_path(expand('<afile>'), "
          \ .string(event) . ")"
  endfor
endfunction"}}}
function! dein#_get_base_path() abort "{{{
  return s:base_path
endfunction"}}}
function! dein#_get_runtime_path() abort "{{{
  return s:runtime_path
endfunction"}}}

call dein#_init()

function! dein#begin(path) abort "{{{
  if a:path == '' || s:block_level != 0
    call dein#_error('Invalid begin/end block usage.')
    return 1
  endif

  let s:block_level += 1
  let s:base_path = dein#_chomp(dein#_expand(a:path))
  let s:runtime_path = a:path . '/.dein'

  if !isdirectory(s:runtime_path)
    call mkdir(s:runtime_path, 'p')
  endif

  call dein#_filetype_off()

  " Join to the tail in runtimepath.
  execute 'set rtp-='.fnameescape(s:runtime_path)
  let rtps = dein#_split_rtp(&runtimepath)
  let n = index(rtps, $VIMRUNTIME)
  if n < 0
    call dein#_error('Invalid runtimepath.')
    return 1
  endif
  let &runtimepath = dein#_join_rtp(
        \ insert(rtps, s:runtime_path, n-1), &runtimepath, s:runtime_path)
endfunction"}}}

function! dein#end() abort "{{{
  if s:block_level != 1
    call dein#_error('Invalid begin/end block usage.')
    return 1
  endif

  let s:block_level -= 1

  " Add runtimepath
  let rtps = dein#_split_rtp(&runtimepath)
  let index = index(rtps, s:runtime_path)
  if index < 0
    call dein#_error('Invalid runtimepath.')
    return 1
  endif
  for plugin in filter(values(g:dein#_plugins),
        \ '!v:val.lazy && !v:val.sourced && isdirectory(v:val.rtp)')
    " Load dependencies
    for name in plugin.depends
      if !has_key(g:dein#_plugins, name)
        call dein#_error(printf('Plugin name "%s" is not found.', name))
        return 1
      endif

      let depend = g:dein#_plugins[name]
      if depend.sourced
        continue
      endif

      call insert(rtps, depend.rtp, index)
      if isdirectory(depend.rtp.'/after')
        call add(rtps, depend.rtp.'/after')
      endif
      let depend.sourced = 1
    endfor

    call insert(rtps, plugin.rtp, index)
    if isdirectory(plugin.rtp.'/after')
      call add(rtps, plugin.rtp.'/after')
    endif
    let plugin.sourced = 1
  endfor
  let &runtimepath = dein#_join_rtp(rtps, &runtimepath, '')
endfunction"}}}

function! dein#add(repo, ...) abort "{{{
  if s:block_level != 1
    call dein#_error('Invalid add usage.')
    return 1
  endif

  let plugin = dein#parse#_dict(
        \ dein#parse#_init(a:repo, get(a:000, 0, {})))
  if (has_key(g:dein#_plugins, plugin.name)
        \ && g:dein#_plugins[plugin.name].sourced)
        \ || !plugin.if
    " Skip already loaded or not enabled plugin.
    return
  endif

  let g:dein#_plugins[plugin.name] = plugin
endfunction"}}}

function! dein#get(...) abort "{{{
  return empty(a:000) ? copy(g:dein#_plugins) : get(g:dein#_plugins, a:1, {})
endfunction"}}}

function! dein#source(...) abort "{{{
  let plugins = empty(a:000) ? copy(g:dein#_plugins)
        \ : map(copy(a:1), 'get(g:dein#_plugins, v:val, {})')
  return dein#autoload#_source(plugins)
endfunction"}}}

function! dein#tap(name) abort "{{{
  return has_key(g:dein#_plugins, a:name)
        \ && isdirectory(g:dein#_plugins[a:name].path)
endfunction"}}}

function! dein#update(...) abort "{{{
  call dein#installer#_update(get(a:000, 0, []))
endfunction"}}}

function! dein#check_install(...) abort "{{{
  let plugins = empty(a:000) ?
        \ values(dein#get()) :
        \ map(copy(a:1), 'dein#get(v:val)')

  call filter(plugins, '!isdirectory(v:val.path)')
  if empty(plugins)
    return 0
  endif

  echomsg 'Not installed plugins: '
        \ string(map(copy(plugins), 'v:val.name'))
  return 1
endfunction"}}}

" Helper functions
function! dein#_has_vimproc() abort "{{{
  if !exists('*vimproc#version')
    try
      call vimproc#version()
    catch
    endtry
  endif

  return exists('*vimproc#version')
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
function! dein#_chomp(str) abort "{{{
  return a:str != '' && a:str[-1:] == '/' ? a:str[: -2] : a:str
endfunction"}}}
function! dein#_filetype_off() abort "{{{
  let filetype_out = dein#_redir('filetype')

  if filetype_out =~# 'plugin:ON'
        \ || filetype_out =~# 'indent:ON'
    filetype plugin indent off
  endif

  if filetype_out =~# 'detection:ON'
    filetype off
  endif

  return filetype_out
endfunction"}}}
function! dein#_convert2list(expr) abort "{{{
  return type(a:expr) ==# type([]) ? a:expr :
        \ type(a:expr) ==# type('') ?
        \   (a:expr == '' ? [] : split(a:expr, '\r\?\n', 1))
        \ : [a:expr]
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

" vim: foldmethod=marker
