"=============================================================================
" FILE: autoload.vim
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

function! dein#autoload#_source(plugins) abort "{{{
  let rtps = dein#_split_rtp(&runtimepath)
  let index = index(rtps, dein#_get_runtime_path())
  if index < 0
    return 1
  endif

  for plugin in filter(copy(a:plugins),
        \ '!empty(v:val) && !v:val.sourced && isdirectory(v:val.rtp)')
    if s:source_plugin(rtps, index, plugin)
      return 1
    endif
  endfor

  let &runtimepath = dein#_join_rtp(rtps, &runtimepath, '')
endfunction"}}}

function! dein#autoload#_on_i() abort "{{{
  let plugins = filter(values(dein#get()),
        \ '!v:val.sourced && v:val.on_i')
  call dein#autoload#_source(plugins)
endfunction"}}}
function! dein#autoload#_on_ft() abort "{{{
  for filetype in split(&l:filetype, '\.')
    let plugins = filter(values(dein#get()),
          \ '!v:val.sourced && index(v:val.on_ft, filetype) >= 0')
    call dein#autoload#_source(plugins)
  endfor
endfunction"}}}

function! dein#autoload#_on_path(path, event) abort "{{{
  if a:path == ''
    return
  endif

  let path = a:path
  " For ":edit ~".
  if fnamemodify(path, ':t') ==# '~'
    let path = '~'
  endif

  let path = dein#_expand(path)
  let plugins = filter(values(dein#get()),
        \ "!v:val.sourced &&
        \  !empty(filter(copy(v:val.on_path), 'path =~? v:val'))")
  if empty(plugins)
    return
  endif

  call dein#autoload#_source(plugins)
  execute 'doautocmd' a:event

  if !exists('s:loaded_path') && has('vim_starting')
        \ && dein#_redir('filetype') =~# 'detection:ON'
    " Force enable auto detection if path plugins are loaded
    autocmd dein VimEnter * filetype detect
    let s:loaded_path = 1
  endif
endfunction"}}}

function! dein#autoload#_on_func(name) abort "{{{
  let function_prefix = substitute(a:name, '[^#]*$', '', '')
  if function_prefix =~# '^dein#'
        \ || function_prefix ==# 'vital#'
        \ || has('vim_starting')
    return
  endif

  let lazy_plugins = filter(values(dein#get()), "!v:val.sourced")
  call s:set_function_prefixes(lazy_plugins)

  call dein#autoload#_source(filter(lazy_plugins,
        \  "index(v:val.pre_func, function_prefix) >= 0
        \   || (index(v:val.on_func, a:name) >= 0)"))
endfunction"}}}

function! dein#autoload#_on_pre_cmd(name) abort "{{{
  call dein#autoload#_source(
        \ filter(dein#_get_lazy_plugins(),
        \ "!empty(filter(map(copy(v:val.pre_cmd), 'tolower(v:val)'),
        \   'stridx(tolower(a:name), v:val) == 0'))"))
endfunction"}}}

function! s:source_plugin(rtps, index, plugin) abort "{{{
  let a:plugin.sourced = 1

  " Load dependencies
  for name in a:plugin.depends
    if !has_key(g:dein#_plugins, name)
      call dein#_error(printf('Plugin name "%s" is not found.', name))
      return 1
    endif

    if s:source_plugin(a:rtps, a:index, g:dein#_plugins[name])
      return 1
    endif
  endfor

  for on_source in filter(values(dein#get()),
        \ "!v:val.sourced && index(v:val.on_source, a:plugin.name) >= 0")
    if s:source_plugin(a:rtps, a:index, on_source)
      return 1
    endif
  endfor

  call insert(a:rtps, a:plugin.rtp, a:index)
  if isdirectory(a:plugin.rtp.'/after')
    call add(a:rtps, a:plugin.rtp.'/after')
  endif

  " Reload script files.
  for directory in filter(['plugin', 'after/plugin'],
        \ "isdirectory(a:plugin.rtp.'/'.v:val)")
    for file in split(glob(a:plugin.rtp.'/'.directory.'/**/*.vim'), '\n')
      " Note: "silent!" is required to ignore E122, E174 and E227.
      "       "unsilent" then displays any messages while sourcing.
      execute 'silent! unsilent source' fnameescape(file)
    endfor
  endfor
endfunction"}}}
function! s:set_function_prefixes(plugins) abort "{{{
  for plugin in filter(copy(a:plugins), "empty(v:val.pre_func)")
    let plugin.pre_func =
          \ dein#_uniq(map(split(globpath(
          \  plugin.path, 'autoload/**/*.vim', 1), "\n"),
          \  "substitute(matchstr(
          \   dein#_substitute_path(fnamemodify(v:val, ':r')),
          \         '/autoload/\\zs.*$'), '/', '#', 'g').'#'"))
  endfor
endfunction"}}}

" vim: foldmethod=marker
