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
        \ "!empty(v:val) && !v:val.sourced && v:val.rtp != ''")
    if s:source_plugin(rtps, index, plugin)
      return 1
    endif
  endfor
endfunction"}}}

function! dein#autoload#_on_i() abort "{{{
  let plugins = filter(dein#_get_lazy_plugins(), 'v:val.on_i')
  if !empty(plugins)
    call dein#autoload#_source(plugins)
    doautocmd InsertEnter
  endif
endfunction"}}}

function! dein#autoload#_on_ft() abort "{{{
  for filetype in split(&l:filetype, '\.')
    call dein#autoload#_source(filter(dein#_get_lazy_plugins(),
          \ 'index(v:val.on_ft, filetype) >= 0'))
  endfor
endfunction"}}}

function! dein#autoload#_on_path(path, event) abort "{{{
  let path = a:path
  " For ":edit ~".
  if fnamemodify(path, ':t') ==# '~'
    let path = '~'
  endif

  let path = dein#_expand(path)
  let plugins = filter(dein#_get_lazy_plugins(),
        \ "!empty(filter(copy(v:val.on_path), 'path =~? v:val'))")
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

  let lazy_plugins = dein#_get_lazy_plugins()
  call dein#autoload#_set_function_prefixes(lazy_plugins)

  call dein#autoload#_source(filter(lazy_plugins,
        \  "index(v:val.pre_func, function_prefix) >= 0
        \   || (index(v:val.on_func, a:name) >= 0)"))
endfunction"}}}
function! dein#autoload#_set_function_prefixes(plugins) abort "{{{
  for plugin in filter(copy(a:plugins), "empty(v:val.pre_func)")
    let plugin.pre_func =
          \ dein#_uniq(map(split(globpath(
          \  plugin.path, 'autoload/**/*.vim', 1), "\n"),
          \  "substitute(matchstr(
          \   dein#_substitute_path(fnamemodify(v:val, ':r')),
          \         '/autoload/\\zs.*$'), '/', '#', 'g').'#'"))
  endfor
endfunction"}}}

function! dein#autoload#_on_pre_cmd(name) abort "{{{
  call dein#autoload#_source(
        \ filter(dein#_get_lazy_plugins(),
        \ "!empty(filter(map(copy(v:val.pre_cmd), 'tolower(v:val)'),
        \   'stridx(tolower(a:name), v:val) == 0'))"))
endfunction"}}}

function! dein#autoload#_on_cmd(command, name, args, bang, line1, line2) abort "{{{
  call dein#source(a:name)

  if !exists(':' . a:command)
    call dein#_error(printf('command %s is not found.', a:command))
    return
  endif

  let range = (a:line1 == a:line2) ? '' :
        \ (a:line1 == line("'<") && a:line2 == line("'>")) ?
        \ "'<,'>" : a:line1.",".a:line2

  try
    execute range.a:command.a:bang a:args
  catch /^Vim\%((\a\+)\)\=:E481/
    " E481: No range allowed
    execute a:command.a:bang a:args
  endtry
endfunction"}}}

function! dein#autoload#_on_map(mapping, name, mode) abort "{{{
  let cnt = v:count > 0 ? v:count : ''

  let input = s:get_input()

  call dein#source(a:name)

  if a:mode ==# 'v' || a:mode ==# 'x'
    call feedkeys('gv', 'n')
  elseif a:mode ==# 'o'
    " TODO: omap
    " v:prevcount?
    " Cancel waiting operator mode.
    call feedkeys(v:operator, 'm')
  endif

  call feedkeys(cnt, 'n')

  let mapping = a:mapping
  while mapping =~ '<[[:alnum:]-]\+>'
    let mapping = substitute(mapping, '\c<Leader>',
          \ get(g:, 'mapleader', '\'), 'g')
    let mapping = substitute(mapping, '\c<LocalLeader>',
          \ get(g:, 'maplocalleader', '\'), 'g')
    let ctrl = matchstr(mapping, '<\zs[[:alnum:]-]\+\ze>')
    execute 'let mapping = substitute(
          \ mapping, "<' . ctrl . '>", "\<' . ctrl . '>", "")'
  endwhile
  call feedkeys(mapping . input, 'm')

  return ''
endfunction"}}}

function! dein#autoload#_dummy_complete(arglead, cmdline, cursorpos) abort "{{{
  " Load plugins
  call dein#autoload#_on_pre_cmd(
        \ tolower(matchstr(a:cmdline, '\a\S*')))

  " Print the candidates
  call feedkeys("\<C-d>", 'n')
  return ['']
endfunction"}}}

function! s:source_plugin(rtps, index, plugin) abort "{{{
  let a:plugin.sourced = 1

  let filetype_before = dein#_redir('autocmd FileType')
  let reset_ftplugin = 0

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

  if !empty(a:plugin.dummy_commands)
    for command in a:plugin.dummy_commands
      silent! execute 'delcommand' command[0]
    endfor
    let a:plugin.dummy_commands = []
  endif

  if !empty(a:plugin.dummy_mappings)
    for map in a:plugin.dummy_mappings
      silent! execute map[0].'unmap' map[1]
    endfor
    let a:plugin.dummy_mappings = []
  endif

  call insert(a:rtps, a:plugin.rtp, a:index)
  if isdirectory(a:plugin.rtp.'/after')
    call add(a:rtps, a:plugin.rtp.'/after')
  endif

  let &runtimepath = dein#_join_rtp(a:rtps, &runtimepath, '')

  call dein#_call_hook('source', a:plugin)

  for on_source in filter(dein#_get_lazy_plugins(),
        \ "index(v:val.on_source, a:plugin.name) >= 0")
    if s:source_plugin(a:rtps, a:index, on_source)
      return 1
    endif
  endfor

  if !reset_ftplugin
    let reset_ftplugin = s:is_reset_ftplugin(&filetype, a:plugin.rtp)
  endif

  let filetype_after = dein#_redir('autocmd FileType')

  if reset_ftplugin
    call dein#_reset_ftplugin()
  elseif filetype_before !=# filetype_after
    execute 'doautocmd FileType' &filetype
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

  if !has('vim_starting')
    call dein#_call_hook('post_source', a:plugin)
  endif
endfunction"}}}
function! s:get_input() abort "{{{
  let input = ''
  let termstr = "<M-_>"

  call feedkeys(termstr, 'n')

  let type_num = type(0)
  while 1
    let char = getchar()
    let input .= (type(char) == type_num) ? nr2char(char) : char

    let idx = stridx(input, termstr)
    if idx >= 1
      let input = input[: idx - 1]
      break
    elseif idx == 0
      let input = ''
      break
    endif
  endwhile

  return input
endfunction"}}}

function! s:is_reset_ftplugin(filetype, rtp) abort "{{{
  for filetype in split(a:filetype, '\.')
    for directory in ['ftplugin', 'indent', 'syntax',
          \ 'after/ftplugin', 'after/indent', 'after/syntax']
      let base = a:rtp . '/' . directory
      if filereadable(base.'/'.filetype.'.vim') ||
            \ (directory =~# 'ftplugin$' &&
            \   isdirectory(base . '/' . filetype) ||
            \   glob(base.'/'.filetype.'_*.vim') != '')
        return 1
      endif
    endfor
  endfor

  return 0
endfunction"}}}

" vim: foldmethod=marker
