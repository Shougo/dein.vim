"=============================================================================
" FILE: dein.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
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

function! unite#kinds#dein#define() abort "{{{
  return s:kind
endfunction"}}}

let s:kind = {
      \ 'name': 'dein',
      \ 'action_table': {},
      \ 'parents': ['uri', 'directory'],
      \ 'default_action': 'lcd',
      \}

" Actions "{{{
let s:kind.action_table.preview = {
      \ 'description': 'view the plugin documentation',
      \ 'is_quit': 0,
      \ }
function! s:kind.action_table.preview.func(candidate) abort "{{{
  " Search help files.
  let readme = get(split(globpath(
        \ a:candidate.action__path, 'doc/*.?*', 1), '\n'), 0, '')

  if readme == ''
    " Search README files.
    let readme = get(split(globpath(
          \ a:candidate.action__path, 'README*', 1), '\n'), 0, '')
    if readme == ''
      return
    endif
  endif

  let buflisted = buflisted(
        \ unite#util#escape_file_searching(readme))

  execute 'pedit' fnameescape(readme)

  " Open folds.
  normal! zv
  normal! zt

  if !buflisted
    call unite#add_previewed_buffer_list(
          \ bufnr(unite#util#escape_file_searching(readme)))
  endif
endfunction"}}}
"}}}

" vim: foldmethod=marker
