"=============================================================================
" FILE: git.vim
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

" Global options definition. "{{{
call dein#_set_default(
      \ 'g:dein#types#git#default_protocol', 'https')
"}}}

function! dein#types#git#define() abort "{{{
  return s:type
endfunction"}}}

let s:type = {
      \ 'name' : 'git',
      \ }

function! s:type.init(repository, option) abort "{{{
  let protocol = matchstr(a:repository, '^.\{-}\ze://')
  let name = substitute(a:repository[len(protocol):],
        \   '^://github.com/', '', '')

  if protocol == ''
        \ || a:repository =~# '\<\%(gh\|github\|bb\|bitbucket\):\S\+'
        \ || has_key(a:option, 'type__protocol')
    let protocol = get(a:option, 'type__protocol',
          \ g:dein#types#git#default_protocol)
  endif

  if protocol !=# 'https' && protocol !=# 'ssh'
    call dein#_error(
          \ printf('Repo: %s The protocol "%s" is unsecure and invalid.',
          \ a:repository, protocol))
    return {}
  endif

  let uri = (protocol ==# 'ssh') ?
        \ 'git@github.com:' . name :
        \ protocol . '://github.com/' . name

  if uri !~ '\.git\s*$'
    " Add .git suffix.
    let uri .= '.git'
  endif

  return { 'uri': uri, 'type': 'git' }
endfunction"}}}

" vim: foldmethod=marker
