"=============================================================================
" FILE: parse.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

let s:git = dein#types#git#define()

" Global options definition." "{{{
let g:dein#enable_name_conversion =
      \ get(g:, 'dein#enable_name_conversion', 0)
let g:dein#install_process_timeout =
      \ get(g:, 'dein#install_process_timeout', 120)
"}}}

function! dein#parse#_add(repo, options) abort "{{{
  let plugin = dein#parse#_dict(
        \ dein#parse#_init(a:repo, a:options))
  if (has_key(g:dein#_plugins, plugin.name)
        \ && g:dein#_plugins[plugin.name].sourced)
        \ || !plugin.if
    " Skip already loaded or not enabled plugin.
    return
  endif

  let g:dein#_plugins[plugin.name] = plugin
endfunction"}}}
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
        \ 'base': dein#util#_get_base_path() . '/repos',
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
  let plugin.directory = dein#util#_chomp(plugin.directory)

  if plugin.rev != ''
    let plugin.directory .= '_' . substitute(plugin.rev,
          \ '[^[:alnum:]_-]', '_', 'g')
  endif

  if plugin.base[0:] == '~'
    let plugin.base = dein#util#_expand(plugin.base)
  endif
  let plugin.base = dein#util#_chomp(plugin.base)

  if !has_key(plugin, 'path')
    let plugin.path = plugin.base.'/'.plugin.directory
  endif
  let plugin.path = dein#util#_chomp(plugin.path)

  " Check relative path
  if (!has_key(a:plugin, 'rtp') || a:plugin.rtp != '')
        \ && plugin.rtp !~ '^\%([~/]\|\a\+:\)'
    let plugin.rtp = plugin.path.'/'.plugin.rtp
  endif
  if plugin.rtp[0:] == '~'
    let plugin.rtp = dein#util#_expand(plugin.rtp)
  endif
  let plugin.rtp = dein#util#_chomp(plugin.rtp)

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
    let plugin.merged =
          \ !plugin.lazy && !plugin.local && !has_key(a:plugin, 'if')
          \ && stridx(plugin.rtp, dein#util#_get_base_path()) == 0
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
    let plugin.depends = dein#util#_convert2list(a:plugin.depends)
  endif

  if plugin.lazy
    if !empty(plugin.on_cmd)
      call s:generate_dummy_commands(plugin)
      call dein#util#_add_dummy_commands(plugin)
    endif
    if !empty(plugin.on_map)
      call s:generate_dummy_mappings(plugin)
      call dein#util#_add_dummy_mappings(plugin)
    endif
  endif

  return plugin
endfunction"}}}
function! dein#parse#_load_toml(filename, default) abort "{{{
  try
    let toml = dein#toml#parse_file(dein#util#_expand(a:filename))
  catch /vital: Text.TOML:/
    call dein#util#_error('Invalid toml format: ' . a:filename)
    call dein#util#_error(v:exception)
    return 1
  endtry
  if type(toml) != type({}) || !has_key(toml, 'plugins')
    call dein#util#_error('Invalid toml file: ' . a:filename)
    return 1
  endif

  " Parse.
  for plugin in toml.plugins
    if !has_key(plugin, 'repo')
      call dein#util#_error('No repository plugin data: ' . a:filename)
      return 1
    endif

    let options = extend(plugin, a:default, 'keep')
    call dein#add(plugin.repo, options)
  endfor
endfunction"}}}
function! dein#parse#_local(localdir, options, includes) abort "{{{
  let base = fnamemodify(dein#util#_expand(a:localdir), ':p')
  let directories = []
  for glob in a:includes
    let directories += map(filter(split(glob(base . glob), '\n'),
          \ "isdirectory(v:val)"), "
          \ substitute(dein#util#_substitute_path(
          \   fnamemodify(v:val, ':p')), '/$', '', '')")
  endfor

  for dir in dein#util#_uniq(directories)
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

function! dein#parse#_name_conversion(path) abort "{{{
  return fnamemodify(get(split(a:path, ':'), -1, ''),
        \ ':s?/$??:t:s?\c\.git\s*$??')
endfunction"}}}

" vim: foldmethod=marker
