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

let s:git = dein#types#git#define()

function! dein#parse#_init(repo, options) abort "{{{
  let plugin = s:git.init(a:repo, a:options)
  if empty(plugin)
    let plugin.type = 'none'
    let plugin.local = 1
  endif
  let plugin.repo = a:repo
  let plugin.orig_opts = deepcopy(a:options)
  return extend(plugin, a:options)
endfunction"}}}
function! dein#parse#_dict(plugin) abort "{{{
  let plugin = {
        \ 'type': 'none',
        \ 'uri': '',
        \ 'rev': '',
        \ 'rtp': '',
        \ 'if': 1,
        \ 'sourced': 0,
        \ 'local': 0,
        \ 'force': 0,
        \ 'base': dein#_get_base_path() . '/repos',
        \ 'frozen': 0,
        \ 'depends': [],
        \ 'timeout': g:dein#install_process_timeout,
        \ 'dummy_commands': [],
        \ 'dummy_mappings': [],
        \ 'build': {},
        \ 'on_i': 0,
        \ 'on_ft': [],
        \ 'on_cmd': [],
        \ 'on_func': [],
        \ 'on_map': [],
        \ 'on_path': [],
        \ 'on_source': [],
        \ 'pre_cmd': [],
        \ 'pre_func': [],
        \ }

  call extend(plugin, a:plugin)

  if !has_key(plugin, 'name')
    let plugin.name = dein#parse#_name_conversion(plugin.repo)
  endif

  if !has_key(plugin, 'normalized_name')
    let plugin.normalized_name = substitute(
          \ fnamemodify(plugin.name, ':r'),
          \ '\c^n\?vim[_-]\|[_-]n\?vim$', '', 'g')
  endif

  if !has_key(a:plugin, 'name') && g:dein#enable_name_conversion
    " Use normalized name.
    let plugin.name = plugin.normalized_name
  endif

  if !has_key(plugin, 'directory')
    let plugin.directory = plugin.name
  endif
  let plugin.directory = dein#_chomp(plugin.directory)

  if plugin.rev != ''
    let plugin.directory .= '_' . substitute(plugin.rev,
          \ '[^[:alnum:]_-]', '_', 'g')
  endif

  if plugin.base[0:] == '~'
    let plugin.base = dein#_expand(plugin.base)
  endif
  let plugin.base = dein#_chomp(plugin.base)

  if !has_key(plugin, 'path')
    let plugin.path = plugin.base.'/'.plugin.directory
  endif
  let plugin.path = dein#_chomp(plugin.path)

  " Check relative path
  if (!has_key(a:plugin, 'rtp') || a:plugin.rtp != '')
        \ && plugin.rtp !~ '^\%([~/]\|\a\+:\)'
    let plugin.rtp = plugin.path.'/'.plugin.rtp
  endif
  if plugin.rtp[0:] == '~'
    let plugin.rtp = dein#_expand(plugin.rtp)
  endif
  let plugin.rtp = dein#_chomp(plugin.rtp)

  if !has_key(plugin, 'augroup')
    let plugin.augroup = plugin.normalized_name
  endif

  " Auto convert2list.
  for key in filter([
        \ 'on_ft', 'on_path', 'on_cmd',
        \ 'on_func', 'on_map', 'on_source',
        \ 'pre_cmd', 'pre_func',
        \ ], "type(plugin[v:val]) != type([])
        \")
    let plugin[key] = [plugin[key]]
  endfor

  " Set lazy flag
  if !has_key(a:plugin, 'lazy')
    let plugin.lazy = plugin.on_i
          \ || !empty(plugin.on_ft)     || !empty(plugin.on_cmd)
          \ || !empty(plugin.on_func)   || !empty(plugin.on_map)
          \ || !empty(plugin.on_path)   || !empty(plugin.on_source)
  endif

  if !has_key(a:plugin, 'merged')
    let plugin.merged = !plugin.lazy && !plugin.local
          \ && stridx(plugin.rtp, dein#_get_base_path()) == 0
  endif

  if empty(plugin.pre_cmd)
    let plugin.pre_cmd = [substitute(
          \ plugin.normalized_name, '[_-]', '', 'g')]
  endif

  " Set if flag
  if has_key(a:plugin, 'if') && type(a:plugin.if) == type('')
    sandbox let plugin.if = eval(a:plugin.if)
  endif

  if has_key(a:plugin, 'depends')
    let plugin.depends = dein#_convert2list(a:plugin.depends)
  endif

  if plugin.lazy
    if !empty(plugin.on_cmd)
      call dein#_add_dummy_commands(plugin)
    endif
    if !empty(plugin.on_map)
      call dein#_add_dummy_mappings(plugin)
    endif
  endif

  return plugin
endfunction"}}}
function! dein#parse#_load_toml(filename, default) abort "{{{
  try
    let toml = dein#toml#parse_file(dein#_expand(a:filename))
  catch /vital: Text.TOML:/
    call dein#_error('Invalid toml format: ' . a:filename)
    call dein#_error(v:exception)
    return 1
  endtry
  if type(toml) != type({}) || !has_key(toml, 'plugins')
    call dein#_error('Invalid toml file: ' . a:filename)
    return 1
  endif

  " Parse.
  for plugin in toml.plugins
    if !has_key(plugin, 'repo')
      call dein#_error('No repository plugin data: ' . a:filename)
      return 1
    endif

    let options = extend(plugin, a:default, 'keep')
    call dein#add(plugin.repo, options)
  endfor
endfunction"}}}
function! dein#parse#_local(localdir, options, includes) abort "{{{
  let base = fnamemodify(dein#_expand(a:localdir), ':p')
  let directories = []
  for glob in a:includes
    let directories += map(filter(split(glob(base . glob), '\n'),
          \ "isdirectory(v:val)"), "
          \ substitute(dein#_substitute_path(
          \   fnamemodify(v:val, ':p')), '/$', '', '')")
  endfor

  for dir in dein#_uniq(directories)
    let options = extend({ 'local': 1, 'base': base,
          \ 'name': fnamemodify(dir, ':t') }, a:options)

    let plugin = dein#get(options.name)
    if !empty(plugin)
      if plugin.sourced
        " Ignore already sourced plugins
        continue
      endif

      call extend(options, copy(plugin.orig_opts), 'keep')
    endif

    call dein#add(dir, options)
  endfor
endfunction"}}}

function! dein#parse#_name_conversion(path) abort "{{{
  return fnamemodify(get(split(a:path, ':'), -1, ''),
        \ ':s?/$??:t:s?\c\.git\s*$??')
endfunction"}}}

" vim: foldmethod=marker
