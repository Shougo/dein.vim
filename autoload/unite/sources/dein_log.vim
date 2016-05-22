"=============================================================================
" FILE: dein/log.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" License: MIT license
"=============================================================================

function! unite#sources#dein_log#define() abort "{{{
  return s:source
endfunction"}}}

let s:source = {
      \ 'name' : 'dein/log',
      \ 'description' : 'print previous dein install logs',
      \ 'syntax' : 'uniteSource__deinLog',
      \ 'hooks' : {},
      \ }

function! s:source.hooks.on_syntax(args, context) abort "{{{
  syntax match uniteSource__deinLog_Message /.*/
        \ contained containedin=uniteSource__deinLog
  highlight default link uniteSource__deinLog_Message Comment
  syntax match uniteSource__deinLog_Progress /(.\{-}):\s*.*/
        \ contained containedin=uniteSource__deinLog
  highlight default link uniteSource__deinLog_Progress String
  syntax match uniteSource__deinLog_Source /|.\{-}|/
        \ contained containedin=uniteSource__deinLog_Progress
  highlight default link uniteSource__deinLog_Source Type
  syntax match uniteSource__deinLog_URI /-> diff URI/
        \ contained containedin=uniteSource__deinLog
  highlight default link uniteSource__deinLog_URI Underlined
endfunction"}}}

function! s:source.gather_candidates(args, context) abort "{{{
  return map(copy(dein#install#_get_log()), "{
        \ 'word' : (v:val =~ '^\\s*\\h\\w*://' ? ' -> diff URI' : v:val),
        \ 'kind' : (v:val =~ '^\\s*\\h\\w*://' ? 'uri' : 'word'),
        \ 'action__uri' : substitute(v:val, '^\\s\\+', '', ''),
        \ }")
endfunction"}}}

