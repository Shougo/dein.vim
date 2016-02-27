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
function! dein#_is_windows() abort "{{{
  return s:is_windows
endfunction"}}}
function! dein#_is_mac() abort "{{{
  return !s:is_windows && !has('win32unix')
      \ && (has('mac') || has('macunix') || has('gui_macvim') ||
      \   (!isdirectory('/proc') && executable('sw_vers')))
endfunction"}}}
function! dein#_is_cygwin() abort "{{{
  return has('win32unix')
endfunction"}}}

" Global options definition." "{{{
let g:dein#enable_name_conversion =
      \ get(g:, 'dein#enable_name_conversion', 0)
let g:dein#install_max_processes =
      \ get(g:, 'dein#install_max_processes', 8)
let g:dein#install_process_timeout =
      \ get(g:, 'dein#install_process_timeout', 120)
let g:dein#install_progress_type =
      \ get(g:, 'dein#install_progress_type', 'statusline')
"}}}

function! dein#_init() abort "{{{
  let s:runtime_path = ''
  let s:base_path = ''
  let s:block_level = 0
  let g:dein#_plugins = {}
  let g:dein#name = ''

  augroup dein
    autocmd!
    autocmd InsertEnter * call dein#autoload#_on_i()
    autocmd FileType * call s:on_ft()
    autocmd FuncUndefined * call s:on_func(expand('<afile>'))
    autocmd VimEnter * call dein#_call_hook('post_source')
  augroup END

  if exists('##CmdUndefined')
    autocmd CmdUndefined *
          \ call dein#autoload#_on_pre_cmd(expand('<afile>'))
  endif

  for event in [
        \ 'BufRead', 'BufCreate', 'BufEnter',
        \ 'BufWinEnter', 'BufNew', 'VimEnter'
        \ ]
    execute 'autocmd dein' event
          \ "* call s:on_path(expand('<afile>'), " .string(event) . ")"
  endfor
endfunction"}}}
function! dein#_get_base_path() abort "{{{
  return s:base_path
endfunction"}}}
function! dein#_get_runtime_path() abort "{{{
  if !isdirectory(s:runtime_path)
    call mkdir(s:runtime_path, 'p')
  endif

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
  let s:runtime_path = s:base_path . '/.dein'

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
        \ "!v:val.lazy && !v:val.sourced && v:val.rtp != ''")
    " Load dependencies
    if !empty(plugin.depends)
      if s:load_depends(plugin, rtps, index)
        return 1
      endif
      continue
    endif

    if !plugin.merged
      call insert(rtps, plugin.rtp, index)
      if isdirectory(plugin.rtp.'/after')
        call add(rtps, plugin.rtp.'/after')
      endif
    endif

    let plugin.sourced = 1
    call add(sourced, plugin)
  endfor
  let &runtimepath = dein#_join_rtp(rtps, &runtimepath, '')

  call dein#_call_hook('source', sourced)

  if !has('vim_starting')
    call dein#_call_hook('post_source')
    call dein#_reset_ftplugin()
  endif
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
  if plugin.force
    call dein#autoload#_source([plugin])
  endif
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
  if !has_key(g:dein#_plugins, a:name)
        \ || !isdirectory(g:dein#_plugins[a:name].path)
    return 0
  endif

  let g:dein#name = a:name
  return 1
endfunction"}}}

function! dein#is_sourced(name) abort "{{{
  return get(get(g:dein#_plugins, a:name, {}), 'sourced', 0)
endfunction"}}}

function! dein#save_cache() abort "{{{
  if dein#_get_base_path() == '' || !exists('s:vimrcs')
    " Ignore
    return 1
  endif

  " Set function prefixes before save cache
  call dein#autoload#_set_function_prefixes(dein#_get_lazy_plugins())

  let plugins = deepcopy(dein#get())
  for plugin in values(plugins)
    let plugin.sourced = 0
  endfor

  let current_vim = dein#_redir('version')

  call writefile([s:get_cache_version(),
        \ current_vim, string(s:vimrcs), string(plugins)],
        \ dein#_get_cache_file())
endfunction"}}}
function! dein#load_cache(...) abort "{{{
  let s:vimrcs = len(a:000) == 0 ? [$MYVIMRC] : a:1

  let cache = dein#_get_cache_file()
  if !filereadable(cache) | return 1 | endif

  if !empty(filter(map(copy(s:vimrcs), 'getftime(dein#_expand(v:val))'),
        \ 'getftime(cache) < v:val'))
    return 1
  endif

  let current_vim = dein#_redir('version')

  try
    let list = readfile(cache)
    let ver = list[0]
    let vim = get(list, 1, '')
    let vimrcs = get(list, 2, '')

    if len(list) != 4
          \ || ver !=# s:get_cache_version()
          \ || current_vim !=# vim
          \ || string(s:vimrcs) !=# vimrcs
      call dein#clear_cache()
      return 1
    endif

    sandbox let plugins = eval(list[3])

    if type(plugins) != type({})
      call dein#clear_cache()
      return 1
    endif

    let g:dein#_plugins = plugins
    let forced_plugins = filter(values(g:dein#_plugins), 'v:val.force')
    if !empty(forced_plugins)
      call dein#autoload#_source(forced_plugins)
    endif
    for plugin in filter(dein#_get_lazy_plugins(),
          \ '!empty(v:val.on_cmd) || !empty(v:val.on_map)')
      if !empty(plugin.on_cmd)
        call dein#_add_dummy_commands(plugin)
      endif
      if !empty(plugin.on_map)
        call dein#_add_dummy_mappings(plugin)
      endif
    endfor
  catch
    call dein#_error('Error occurred while loading cache : ' . v:exception)
    call dein#clear_cache()
    return 1
  endtry
endfunction"}}}
function! dein#clear_cache() abort "{{{
  let cache = dein#_get_cache_file()
  if !filereadable(cache)
    return
  endif

  call delete(cache)
endfunction"}}}
function! dein#_get_cache_file() abort "{{{
  return dein#_get_base_path() . '/cache_' . v:progname
endfunction"}}}
let s:parser_vim_path = fnamemodify(expand('<sfile>'), ':h')
      \ . '/dein/parser.vim'
function! s:get_cache_version() abort "{{{
  return getftime(s:parser_vim_path)
endfunction "}}}

function! dein#install(...) abort "{{{
  call dein#install#_update(get(a:000, 0, []), 0,
        \ has('nvim') && !has('vim_starting'))
endfunction"}}}
function! dein#update(...) abort "{{{
  call dein#install#_update(get(a:000, 0, []), 1,
        \ has('nvim') && !has('vim_starting'))
endfunction"}}}
function! dein#reinstall(plugins) abort "{{{
  call dein#install#_reinstall(a:plugins)
endfunction"}}}
function! dein#remote_plugins() abort "{{{
  if !has('nvim')
    return
  endif

  " Load not loaded neovim remote plugins
  call dein#autoload#_source(filter(
        \ values(dein#get()),
        \ "isdirectory(v:val.rtp . '/rplugin')"))

  if exists(':UpdateRemotePlugins')
    UpdateRemotePlugins
  endif
endfunction"}}}
function! dein#recache_runtimepath() abort "{{{
  call dein#install#_recache_runtimepath()
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
function! dein#check_lazy_plugins() abort "{{{
  let no_meaning_plugins = map(filter(dein#_get_lazy_plugins(),
        \   "!v:val.local && isdirectory(v:val.rtp)
        \    && !isdirectory(v:val.rtp . '/plugin')
        \    && !isdirectory(v:val.rtp . '/after/plugin')"),
        \   'v:val.name')
  echomsg 'No meaning lazy plugins: ' string(no_meaning_plugins)
  return len(no_meaning_plugins)
endfunction"}}}

function! dein#load_toml(filename, ...) abort "{{{
  return dein#parse#_load_toml(a:filename, get(a:000, 0, {}))
endfunction"}}}

function! dein#get_log() abort "{{{
  return join(dein#install#_get_log(), "\n")
endfunction"}}}
function! dein#get_updates_log() abort "{{{
  return join(dein#install#_get_updates_log(), "\n")
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
  let prefix = '#User#dein#'.a:hook_name.'#'
  let plugins = filter(dein#_convert2list(
        \ (empty(a:000) ? dein#get() : a:1)),
        \ "get(v:val, 'sourced', 0) && exists(prefix . v:val.name)")

  for plugin in dein#_tsort(plugins)
    let autocmd = 'dein#' . a:hook_name . '#' . plugin.name
    if exists('#User#'.autocmd)
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
  if dein#_is_sudo() || !filewritable(dein#_get_base_path())
    return 1
  endif

  let path = dein#_get_base_path() . '/' . a:path
  let dir = fnamemodify(path, ':h')
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif

  return writefile(a:list, path)
endfunction"}}}
function! dein#_add_dummy_commands(plugin) abort "{{{
  if empty(a:plugin.dummy_commands)
    call s:generate_dummy_commands(a:plugin)
  endif
  for command in a:plugin.dummy_commands
    silent! execute command[1]
  endfor
endfunction"}}}
function! s:generate_dummy_commands(plugin) abort "{{{
  for name in a:plugin.on_cmd
    " Define dummy commands.
    let raw_cmd = 'command '
          \ . '-complete=customlist,dein#autoload#_dummy_complete'
          \ . ' -bang -bar -range -nargs=* '. name
          \ . printf(" call dein#autoload#_on_cmd(%s, %s, <q-args>,
          \  expand('<bang>'), expand('<line1>'), expand('<line2>'))",
          \   string(name), string(a:plugin.name))

    call add(a:plugin.dummy_commands, [name, raw_cmd])
  endfor
endfunction"}}}
function! dein#_add_dummy_mappings(plugin) abort "{{{
  if empty(a:plugin.dummy_mappings)
    call s:generate_dummy_mappings(a:plugin)
  endif
  for mapping in a:plugin.dummy_mappings
    silent! execute mapping[2]
  endfor
endfunction"}}}
function! s:generate_dummy_mappings(plugin) abort "{{{
  for [modes, mappings] in map(copy(a:plugin.on_map), "
        \   type(v:val) == type([]) ?
        \     [split(v:val[0], '\\zs'), v:val[1:]] :
        \     [['n', 'x', 'o'], [v:val]]
        \ ")
    if mappings ==# ['<Plug>']
      " Use plugin name.
      let mappings = ['<Plug>(' . a:plugin.normalized_name]
      if stridx(a:plugin.normalized_name, '-') >= 0
        " The plugin mappings may use "_" instead of "-".
        call add(mappings, '<Plug>(' .
              \ substitute(a:plugin.normalized_name, '-', '_', 'g'))
      endif
    endif

    for mapping in mappings
      " Define dummy mappings.
      let prefix = printf("call dein#autoload#_on_map(%s, %s,",
            \ string(substitute(mapping, '<', '<lt>', 'g')),
            \ string(a:plugin.name))
      for mode in modes
        let raw_map = mode.'noremap <unique><silent> '.mapping
            \ . (mode ==# 'c' ? " \<C-r>=" :
            \    mode ==# 'i' ? " \<C-o>:" : " :\<C-u>") . prefix
            \ . string(mode) . ")<CR>"
        call add(a:plugin.dummy_mappings, [mode, mapping, raw_map])
      endfor
    endfor
  endfor
endfunction"}}}
function! dein#_get_type(name) abort "{{{
  return get({'git': dein#types#git#define()}, a:name, {})
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
  if empty(a:target) || has_key(a:mark, a:target.name)
    return
  endif

  let a:mark[a:target.name] = 1
  for depend in a:target.depends
    call s:tsort_impl(dein#get(depend), a:mark, a:sorted)
  endfor

  call add(a:sorted, a:target)
endfunction"}}}

function! s:on_path(path, event) abort "{{{
  if a:path == ''
    return
  endif

  call dein#autoload#_on_path(a:path, a:event)
endfunction"}}}
function! s:on_ft() abort "{{{
  if &filetype == ''
    return
  endif

  call dein#autoload#_on_ft()
endfunction"}}}
function! s:on_func(name) abort "{{{
  let function_prefix = substitute(a:name, '[^#]*$', '', '')
  if function_prefix =~# '^dein#'
        \ || function_prefix ==# 'vital#'
        \ || has('vim_starting')
    return
  endif

  call dein#autoload#_on_func(a:name)
endfunction"}}}

function! s:load_depends(plugin, rtps, index) abort "{{{
  for name in a:plugin.depends
    if !has_key(g:dein#_plugins, name)
      call dein#_error(printf('Plugin name "%s" is not found.', name))
      return 1
    endif
  endfor

  for depend in dein#_tsort([a:plugin])
    if depend.sourced
      return
    endif

    let depend.sourced = 1

    if !depend.merged
      call insert(a:rtps, depend.rtp, a:index)
      if isdirectory(depend.rtp.'/after')
        call add(a:rtps, depend.rtp.'/after')
      endif
    endif
  endfor
endfunction"}}}

" vim: foldmethod=marker
