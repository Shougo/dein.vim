function! dein#autoload#_source(plugins) abort
  let plugins = dein#util#_convert2list(a:plugins)
  if plugins->empty()
    return []
  endif

  if plugins[0]->type() != v:t_dict
    let plugins = dein#util#_convert2list(a:plugins)
          \ ->map({ _, val -> g:dein#_plugins->get(val, {}) })
  endif

  let rtps = dein#util#_split_rtp(&runtimepath)
  const index = rtps->index(dein#util#_get_runtime_path())
  if index < 0
    return []
  endif

  let sourced = []
  for plugin in plugins
        \ ->filter({ _, val ->
        \  !(val->empty()) && !val.sourced && val.rtp !=# ''
        \  && (!(v:val->has_key('if')) || v:val.if->eval())
        \  && v:val.path->isdirectory()
        \ })
    call s:source_plugin(rtps, index, plugin, sourced)
  endfor

  const filetype_before = 'autocmd FileType'->execute()
  let &runtimepath = dein#util#_join_rtp(rtps, &runtimepath, '')

  call dein#call_hook('source', sourced)

  " Reload script files.
  for plugin in sourced
    for directory in ['ftdetect', 'after/ftdetect', 'plugin', 'after/plugin']
          \ ->filter({ _, val -> (plugin.rtp .. '/' .. val)->isdirectory() })
          \ ->map({ _, val -> plugin.rtp .. '/' .. val })
      if directory =~# 'ftdetect'
        if !(plugin->get('merge_ftdetect'))
          execute 'augroup filetypedetect'
        endif
      endif
      let files = (directory .. '/**/*.vim')->glob(v:true, v:true)
      if has('nvim')
        let files += (directory .. '/**/*.lua')->glob(v:true, v:true)
      endif
      for file in files
        execute 'source' file->fnameescape()
      endfor
      if directory =~# 'ftdetect'
        execute 'augroup END'
      endif
    endfor

    if !has('vim_starting')
      let augroup = plugin->get('augroup', plugin.normalized_name)
      let events = ['VimEnter', 'BufRead', 'BufEnter',
            \ 'BufWinEnter', 'WinEnter']
      if has('gui_running') && &term ==# 'builtin_gui'
        call add(events, 'GUIEnter')
      endif
      for event in events
        if ('#' .. augroup .. '#' .. event)->exists()
          silent execute 'doautocmd' augroup event
        endif
      endfor

      " Register for lazy loaded denops plugin
      if (plugin.rtp .. '/denops')->isdirectory()
        for name in 'denops/*/main.ts'
              \ ->globpath(plugin.rtp, v:true, v:true)
              \ ->map({ _, val -> val->fnamemodify(':h:t')})
              \ ->filter({ _, val -> !denops#plugin#is_loaded(val) })

          if denops#server#status() ==# 'running'
            try
              call denops#plugin#load(
                    \  name,
                    \  [plugin.rtp, 'denops', name, 'main.ts']->join(s:sep),
                    \)
            catch /^Vim\%((\a\+)\)\=:E117:/
              " Fallback to `register` for backward compatibility
              silent! call denops#plugin#register(
                    \  name,
                    \  [plugin.rtp, 'denops', name, 'main.ts']->join(s:sep),
                    \  #{ mode: 'skip' },
                    \)
            endtry
          endif

          if plugin->get('denops_wait', v:true)
            call denops#plugin#wait(name)
            redraw
          endif
        endfor
      endif
    endif
  endfor

  const filetype_after = 'autocmd FileType'->execute()

  const is_reset = s:is_reset_ftplugin(sourced)
  if is_reset
    " NOTE: filetype plugins must be reset to load new ftplugins
    call s:reset_ftplugin()
  endif

  if (is_reset || filetype_before !=# filetype_after) && &l:filetype !=# ''
    " Recall FileType autocmd
    let &l:filetype = &l:filetype
  endif

  if !has('vim_starting')
    call dein#call_hook('post_source', sourced)
  endif

  return sourced
endfunction

function! dein#autoload#_on_default_event(event) abort
  let lazy_plugins = dein#util#_get_lazy_plugins()
  let plugins = []

  let path = '<afile>'->expand()
  " For ":edit ~".
  if path->fnamemodify(':t') ==# '~'
    let path = '~'
  endif
  let path = dein#util#_expand(path)

  for filetype in &l:filetype->split('\.')
    let plugins += lazy_plugins->copy()
          \ ->filter({ _, val -> val->get('on_ft', [])
          \ ->index(filetype) >= 0 })
  endfor

  let plugins += lazy_plugins->copy()
        \ ->filter({ _, val -> !(val->get('on_path', [])->copy()
        \ ->filter({ _, val -> path =~? val })->empty()) })
  let plugins += lazy_plugins->copy()
        \ ->filter({ _, val ->
        \   !(val->has_key('on_event')) && val->has_key('on_if')
        \   && val.on_if->eval() })

  call s:source_events(a:event, plugins)
endfunction
function! dein#autoload#_on_event(event, plugins) abort
  let lazy_plugins = dein#util#_get_plugins(a:plugins)
        \ ->filter({ _, val -> !val.sourced })
  if lazy_plugins->empty()
    execute 'autocmd! dein-events' a:event
    return
  endif

  let plugins = lazy_plugins->copy()
        \ ->filter({ _, val ->
        \          !(val->has_key('on_if')) || val.on_if->eval() })
  call s:source_events(a:event, plugins)
endfunction
function! s:source_events(event, plugins) abort
  if empty(a:plugins)
    return
  endif

  const prev_autocmd = ('autocmd ' .. a:event)->execute()

  call dein#autoload#_source(a:plugins)

  const new_autocmd = ('autocmd ' .. a:event)->execute()

  if a:event ==# 'InsertCharPre'
    " Queue this key again
    call feedkeys(v:char)
    let v:char = ''
  else
    if '#BufReadCmd'->exists() && a:event ==# 'BufNew'
      " For BufReadCmd plugins
      silent doautocmd <nomodeline> BufReadCmd
    endif
    if ('#' .. a:event)->exists() && prev_autocmd !=# new_autocmd
      execute 'doautocmd <nomodeline>' a:event
    elseif ('#User#' .. a:event)->exists()
      execute 'doautocmd <nomodeline> User' a:event
    endif
  endif
endfunction

function! dein#autoload#_on_func(name) abort
  const function_prefix = a:name->substitute('[^#]*$', '', '')
  if function_prefix =~# '^dein#'
        \ || (function_prefix =~# '^vital#' &&
        \     function_prefix !~# '^vital#vital#')
    return
  endif

  call dein#autoload#_source(dein#util#_get_lazy_plugins()
        \ ->filter({ _, val ->
        \          function_prefix->stridx(val.normalized_name.'#') == 0
        \          || val->get('on_func', [])->index(a:name) >= 0 }))
endfunction

function! dein#autoload#_on_lua(name) abort
  if g:dein#_called_lua->has_key(a:name)
    return
  endif

  " Only use the root of module name.
  const mod_root = a:name->matchstr('^[^./]\+')

  " Prevent infinite loop
  let g:dein#_called_lua[a:name] = v:true

  call dein#autoload#_source(dein#util#_get_lazy_plugins()
        \ ->filter({ _, val -> val->get('on_lua', [])->index(mod_root) >= 0 }))
endfunction

function! dein#autoload#_on_pre_cmd(name) abort
  call dein#autoload#_source(
        \ dein#util#_get_lazy_plugins()
        \  ->filter({ _, val -> copy(val->get('on_cmd', []))
        \  ->map({ _, val2 -> tolower(val2) })
        \  ->index(a:name) >= 0
        \  || a:name->tolower()
        \     ->stridx(val.normalized_name->tolower()
        \     ->substitute('[_-]', '', 'g')) == 0 }))
endfunction

function! dein#autoload#_on_cmd(command, name, args, bang, line1, line2) abort
  call dein#source(a:name)

  if (':' .. a:command)->exists() != 2
    call dein#util#_error(printf('command %s is not found.', a:command))
    return
  endif

  const range = (a:line1 == a:line2) ? '' :
        \ (a:line1 == "'<"->line() && a:line2 == "'>"->line()) ?
        \ "'<,'>" : a:line1 .. ',' .. a:line2

  try
    execute range.a:command.a:bang a:args
  catch /^Vim\%((\a\+)\)\=:E481/
    " E481: No range allowed
    execute a:command.a:bang a:args
  endtry
endfunction

function! dein#autoload#_on_map(mapping, name, mode) abort
  const cnt = v:count > 0 ? v:count : ''

  const input = s:get_input()

  const sourced = dein#source(a:name)
  if sourced->empty()
    " Prevent infinite loop
    silent! execute a:mode.'unmap' a:mapping
  endif

  if a:mode ==# 'v' || a:mode ==# 'x'
    call feedkeys('gv', 'n')
  elseif a:mode ==# 'o' && v:operator !=# 'c'
    const save_operator = v:operator
    call feedkeys("\<Esc>", 'in')

    " Cancel waiting operator mode.
    call feedkeys(save_operator, 'imx')
  endif

  call feedkeys(cnt, 'n')

  if a:mode ==# 'o' && v:operator ==# 'c'
    " NOTE: This is the dirty hack.
    execute s:mapargrec(a:mapping .. input, a:mode)->matchstr(
          \ ':<C-u>\zs.*\ze<CR>')
  else
    let mapping = a:mapping
    while mapping =~# '<[[:alnum:]_-]\+>'
      let mapping = mapping->substitute('\c<Leader>',
            \ g:->get('mapleader', '\'), 'g')
      let mapping = mapping->substitute('\c<LocalLeader>',
            \ g:->get('maplocalleader', '\'), 'g')
      let ctrl = mapping->matchstr('<\zs[[:alnum:]_-]\+\ze>')
      execute 'let mapping = mapping->substitute(
            \ "<' .. ctrl .. '>", "\<' .. ctrl .. '>", "")'
    endwhile

    if a:mode ==# 't'
      call feedkeys('i', 'n')
    endif
    call feedkeys(mapping .. input, 'm')
  endif

  return ''
endfunction

function! dein#autoload#_dummy_complete(arglead, cmdline, cursorpos) abort
  const command = a:cmdline->matchstr('\h\w*')
  if (':' .. command)->exists() == 2
    " Remove the dummy command.
    silent! execute 'delcommand' command
  endif

  " Load plugins
  call dein#autoload#_on_pre_cmd(tolower(command))

  return a:arglead
endfunction

function! s:source_plugin(rtps, index, plugin, sourced) abort
  if a:plugin.sourced || a:sourced->index(a:plugin) >= 0
    \ || (a:plugin->has_key('if') && !(a:plugin.if->eval()))
    return
  endif

  call insert(a:sourced, a:plugin)

  let index = a:index

  " NOTE: on_source must sourced after depends
  for on_source in dein#util#_get_lazy_plugins()
        \ ->filter({ _, val ->
        \          val->get('on_source', []) ->index(a:plugin.name) >= 0
        \ })
    if s:source_plugin(a:rtps, index, on_source, a:sourced)
      let index += 1
    endif
  endfor

  " Load dependencies
  for name in a:plugin->get('depends', [])
    if !(g:dein#_plugins->has_key(name))
      call dein#util#_error(printf(
            \ 'Plugin "%s" depends "%s" but it is not found.',
            \ a:plugin.name, name))
      continue
    endif

    if !a:plugin.lazy && g:dein#_plugins[name].lazy
      call dein#util#_error(printf(
            \ 'Not lazy plugin "%s" depends lazy "%s" plugin.',
            \ a:plugin.name, name))
      continue
    endif

    if s:source_plugin(a:rtps, index, g:dein#_plugins[name], a:sourced)
      let index += 1
    endif
  endfor

  let a:plugin.sourced = 1

  if a:plugin->has_key('dummy_commands')
    for command in a:plugin.dummy_commands
      silent! execute 'delcommand' command[0]
    endfor
    let a:plugin.dummy_commands = []
  endif

  if a:plugin->has_key('dummy_mappings')
    for map in a:plugin.dummy_mappings
      silent! execute map[0].'unmap' map[1]
    endfor
    let a:plugin.dummy_mappings = []
  endif

  if !a:plugin.merged || a:plugin->get('local', 0)
    call insert(a:rtps, a:plugin.rtp, index)
    if (a:plugin.rtp .. '/after')->isdirectory()
      call dein#util#_add_after(a:rtps, a:plugin.rtp .. '/after')
    endif
  endif

  if g:->get('dein#lazy_rplugins', v:false) && !g:dein#_loaded_rplugins
        \ && (a:plugin.rtp .. '/rplugin')->isdirectory()
    " Enable remote plugin
    unlet! g:loaded_remote_plugins

    runtime! plugin/rplugin.vim

    let g:dein#_loaded_rplugins = v:true
  endif
endfunction
function! s:reset_ftplugin() abort
  const filetype_state = 'filetype'->execute()

  if 'b:did_indent'->exists() || 'b:did_ftplugin'->exists()
    filetype plugin indent off
  endif

  if filetype_state =~# 'plugin:ON'
    silent! filetype plugin on
  endif

  if filetype_state =~# 'indent:ON'
    silent! filetype indent on
  endif
endfunction
function! s:get_input() abort
  let input = ''
  const termstr = '<M-_>'

  call feedkeys(termstr, 'n')

  while 1
    let char = getchar()
    let input ..= (char->type() == v:t_number) ? char->nr2char() : char

    let idx = input->stridx(termstr)
    if idx >= 1
      let input = input[: idx - 1]
      break
    elseif idx == 0
      let input = ''
      break
    endif
  endwhile

  return input
endfunction

function! s:is_reset_ftplugin(plugins) abort
  if &l:filetype ==# ''
    return 0
  endif

  for plugin in a:plugins
    let ftplugin = plugin.rtp .. '/ftplugin/' .. &l:filetype
    let after = plugin.rtp .. '/after/ftplugin/' .. &l:filetype
    let check_ftplugin = !(['ftplugin', 'indent',
          \ 'after/ftplugin', 'after/indent',]
          \ ->filter({ _, val -> printf('%s/%s/%s.vim',
          \          plugin.rtp, val, &l:filetype)->filereadable()
          \          || printf('%s/%s/%s.lua',
          \          plugin.rtp, val, &l:filetype)->filereadable()
        \ })->empty())
    if check_ftplugin
          \ || ftplugin->isdirectory() || after->isdirectory()
          \ || (ftplugin .. '_*.vim')->glob(v:true) !=# ''
          \ || (after .. '_*.vim')->glob(v:true) !=# ''
          \ || (ftplugin .. '_*.lua')->glob(v:true) !=# ''
          \ || (after .. '_*.lua')->glob(v:true) !=# ''
      return 1
    endif
  endfor
  return 0
endfunction
function! s:mapargrec(map, mode) abort
  let arg = a:map->maparg(a:mode)
  while arg->maparg(a:mode) !=# ''
    let arg = arg->maparg(a:mode)
  endwhile
  return arg
endfunction
