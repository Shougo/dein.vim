"=============================================================================
" FILE: parse.vim
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

let s:save_cpo = &cpo
set cpo&vim

function! dein#parse#_dict(plugin) abort "{{{
  let plugin = {
        \ 'type': 'none',
        \ 'orig_name': '',
        \ 'uri': '',
        \ 'rev': '',
        \ 'rtp': '',
        \ 'if': '',
        \ 'sourced': 0,
        \ 'local': 0,
        \ 'base': dein#_get_base_path(),
        \ 'frozen': 0,
        \ 'depends': [],
        \ 'hooks': {},
        \ 'dummy_commands': [],
        \ 'dummy_mappings': [],
        \ 'on_i': 0,
        \ 'on_ft': [],
        \ 'on_cmd': [],
        \ 'on_func': [],
        \ 'on_map': [],
        \ 'on_unite': [],
        \ 'on_path': [],
        \ 'on_source': [],
        \ 'pre_cmd': [],
        \ 'pre_func': [],
        \ }

  call extend(plugin, a:plugin)

  if !has_key(plugin, 'name')
    let plugin.name = dein#parse#_name_conversion(plugin.orig_name)
  endif

  if !has_key(plugin, 'normalized_name')
    let plugin.normalized_name = substitute(
          \ fnamemodify(plugin.name, ':r'),
          \ '\c^n\?vim[_-]\|[_-]n\?vim$', '', 'g')
  endif

  if !has_key(plugin, 'directory')
    let plugin.directory = plugin.name

    if plugin.rev != ''
      let plugin.directory .= '_' . substitute(plugin.rev,
            \ '[^[:alnum:]_-]', '_', 'g')
    endif
  endif

  if plugin.base[0:] == '~'
    let plugin.base = dein#_expand(plugin.base)
  endif
  if plugin.base[-1:] == '/' || plugin.base[-1:] == '\'
    " Chomp.
    let plugin.base = plugin.base[: -2]
  endif

  if !has_key(plugin, 'path')
    let plugin.path = plugin.base.'/'.plugin.directory
  endif

  " Check relative path.
  if plugin.rtp !~ '^\%([~/]\|\a\+:\)'
    let plugin.rtp = plugin.path.'/'.plugin.rtp
  endif
  if plugin.rtp[0:] == '~'
    let plugin.rtp = dein#_expand(plugin.rtp)
  endif
  if plugin.rtp[-1:] == '/' || plugin.rtp[-1:] == '\'
    " Chomp.
    let plugin.rtp = plugin.rtp[: -2]
  endif

  if !has_key(plugin, 'augroup')
    let plugin.augroup = plugin.normalized_name
  endif

  return plugin
endfunction"}}}
function! dein#parse#_list(plugins) abort "{{{
  return map(copy(a:plugins), 'dein#parse#_dict(v:val)')
endfunction"}}}

function! dein#parse#_name_conversion(path) "{{{
  return fnamemodify(get(split(a:path, ':'), -1, ''), ':s?/$??:t:s?\c\.git\s*$??')
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
