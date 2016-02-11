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
function! dein#_uniq(list, ...) abort "{{{
  let list = a:0 ? map(copy(a:list), printf('[v:val, %s]', a:1)) : copy(a:list)
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

" Global options definition." "{{{
let g:dein#install_max_processes =
      \ get(g:, 'dein#install_max_processes', 8)
let g:dein#install_process_timeout =
      \ get(g:, 'dein#install_process_timeout', 8)
"}}}

function! dein#_init() abort "{{{
  let s:runtime_path = ''
  let s:base_path = ''
  let s:block_level = 0
  let g:dein#_plugins = {}

  augroup dein
    autocmd!
    autocmd InsertEnter * call dein#autoload#_on_i()
    autocmd FileType * call dein#autoload#_on_ft()
    autocmd FuncUndefined *
          \ call dein#autoload#_on_func(expand('<amatch>'))
    autocmd VimEnter * call dein#_call_hook('post_source')
  augroup END

  if exists('##CmdUndefined')
    autocmd CmdUndefined *
          \ call dein#autoload#_on_pre_cmd(expand('<amatch>'))
  endif

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
function! dein#_get_tags_path() abort "{{{
  if s:runtime_path == '' || dein#_is_sudo()
    return ''
  endif

  let dir = s:runtime_path . '/doc'
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif
  return dir
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

  let sourced = []
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
    call add(sourced, plugin)
  endfor
  let &runtimepath = dein#_join_rtp(rtps, &runtimepath, '')

  call dein#_call_hook('source', sourced)
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
  return has_key(g:dein#_plugins, a:name)
        \ && isdirectory(g:dein#_plugins[a:name].path)
endfunction"}}}

function! dein#install(...) abort "{{{
  call dein#install#_update(get(a:000, 0, []), 0)
endfunction"}}}
function! dein#update(...) abort "{{{
  call dein#install#_update(get(a:000, 0, []), 1)
endfunction"}}}
function! dein#remote_plugins() abort "{{{
  if !has('nvim')
    return
  endif

  " Load not loaded neovim remote plugins
  call dein#autoload#_source(filter(
        \ values(dein#get()),
        \ "isdirectory(v:val.rtp . '/rplugin')"))

  UpdateRemotePlugins
endfunction"}}}

function! dein#check_install(...) abort "{{{
  let plugins = empty(a:000) ?
        \ values(dein#get()) :
        \ map(copy(a:1), 'dein#get(v:val)')

  call filter(plugins, '!empty(v:val) && !isdirectory(v:val.path)')
  if empty(plugins)
    return 0
  endif

  echomsg 'Not installed plugins: '
        \ string(map(copy(plugins), 'v:val.name'))
  return 1
endfunction"}}}

function! dein#load_toml(filename, ...) abort "{{{
  return dein#parse#_load_toml(a:filename, get(a:000, 0, {}))
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
    filetype plugin indent off
  endif

  if filetype_out =~# 'detection:ON'
    filetype off
  endif

  return filetype_out
endfunction"}}}
function! dein#_reset_ftplugin() abort "{{{
  let filetype_out = dein#_filetype_off()

  if filetype_out =~# 'detection:ON'
        \ && filetype_out =~# 'plugin:ON'
        \ && filetype_out =~# 'indent:ON'
    silent! filetype plugin indent on
  else
    if filetype_out =~# 'detection:ON'
      silent! filetype on
    endif

    if filetype_out =~# 'plugin:ON'
      silent! filetype plugin on
    endif

    if filetype_out =~# 'indent:ON'
      silent! filetype indent on
    endif
  endif

  if filetype_out =~# 'detection:ON'
    filetype detect
  endif

  " Reload filetype plugins.
  let &l:filetype = &l:filetype

  " Recall FileType autocmd
  execute 'doautocmd FileType' &filetype
endfunction"}}}
function! dein#_call_hook(hook_name, ...) abort "{{{
  let plugins = dein#_tsort(filter(dein#_convert2list(
        \ (empty(a:000) ? dein#get() : a:1)), "get(v:val, 'sourced', 0)"))

  for plugin in plugins
    let autocmd = 'dein#' . a:hook_name . '#' . plugin.name
    if exists('#User#' . autocmd)
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
function! dein#_is_sudo() abort "{{{
  return $SUDO_USER != '' && $USER !=# $SUDO_USER
      \ && $HOME !=# expand('~'.$USER)
      \ && $HOME ==# expand('~'.$SUDO_USER)
endfunction"}}}
function! dein#_writefile(path, list) abort "{{{
  if dein#_is_sudo() || !filewritable(dein#_get_runtime_path())
    return 1
  endif

  let path = dein#_get_runtime_path() . '/' . a:path
  let dir = fnamemodify(path, ':h')
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif

  return writefile(a:list, path)
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
  if has_key(a:mark, a:target.name)
    return
  endif

  let a:mark[a:target.name] = 1
  for depend in a:target.depends
    call s:tsort_impl(dein#get(depend), a:mark, a:sorted)
  endfor

  call add(a:sorted, a:target)
endfunction"}}}

" vim: foldmethod=marker
