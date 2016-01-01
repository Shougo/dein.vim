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
      \ 'g:dein#types#git#command_path', 'git')
call dein#_set_default(
      \ 'g:dein#types#git#default_protocol', 'https')
call dein#_set_default(
      \ 'g:dein#types#git#clone_depth', 0)
call dein#_set_default(
      \ 'g:dein#types#git#pull_command', 'pull --ff --ff-only')
"}}}

function! dein#types#git#define() abort "{{{
  return s:type
endfunction"}}}

let s:type = {
      \ 'name' : 'git',
      \ }

function! s:type.init(repo, option) abort "{{{
  let protocol = matchstr(a:repo, '^.\{-}\ze://')
  let name = substitute(a:repo[len(protocol):],
        \   '^://[^/]*/', '', '')

  if protocol == ''
        \ || a:repo =~# '\<\%(gh\|github\|bb\|bitbucket\):\S\+'
        \ || has_key(a:option, 'type__protocol')
    let protocol = get(a:option, 'type__protocol',
          \ g:dein#types#git#default_protocol)
  endif

  if protocol !=# 'https' && protocol !=# 'ssh'
    call dein#_error(
          \ printf('Repo: %s The protocol "%s" is unsecure and invalid.',
          \ a:repo, protocol))
    return {}
  endif

  let uri = (protocol ==# 'ssh') ?
        \ 'git@github.com:' . name :
        \ protocol . '://github.com/' . name

  if uri !~ '\.git\s*$'
    " Add .git suffix.
    let uri .= '.git'
  endif

  return { 'uri': uri, 'type': 'git',
        \  'directory': substitute(uri, '.*:/*', '', '') }
endfunction"}}}

function! s:type.get_sync_command(plugin) abort "{{{
  let git = g:dein#types#git#command_path
  if !executable(git)
    return 'E: "git" command is not installed.'
  endif

  if !isdirectory(a:plugin.path)
    let cmd = 'clone'
    let cmd .= ' --recursive'

    let depth = get(a:plugin, 'type__depth',
          \ g:dein#types#git#clone_depth)
    if depth > 0 && a:plugin.rev == '' && a:plugin.uri !~ '^git@'
      let cmd .= ' --depth=' . depth
    endif

    let cmd .= printf(' %s "%s"', a:plugin.uri, a:plugin.path)
  else
    let shell = fnamemodify(split(&shell)[0], ':t')
    let and = (!dein#_has_vimproc() && shell ==# 'fish') ?
          \ '; and ' : ' && '

    let cmd = g:dein#types#git#pull_command
    let cmd .= and . git . ' submodule update --init --recursive'
  endif

  return git . ' ' . cmd
endfunction"}}}

" vim: foldmethod=marker
