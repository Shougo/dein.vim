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
    echomsg filetype
    call dein#autoload#_source(plugins)
  endfor
endfunction"}}}
function! s:source_plugin(rtps, index, plugin) abort
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
endfunction

" vim: foldmethod=marker
