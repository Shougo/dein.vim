let s:is_windows = has('win32') || has('win64')
let s:merged_length = 3

function! dein#util#_init() abort
endfunction

function! dein#util#_set_default(var, val, alternate_var = '') abort
  if !(a:var->exists()) || {a:var}->type() != a:val->type()
    let {a:var} = a:alternate_var->exists() ? {a:alternate_var} : a:val
  endif
endfunction

function! dein#util#_is_windows() abort
  return s:is_windows
endfunction
function! dein#util#_is_mac() abort
  return !s:is_windows && !has('win32unix')
        \ && (has('mac') || has('macunix') || has('gui_macvim')
        \   || (!('/proc'->isdirectory()) && 'sw_vers'->executable()))
endfunction

function! dein#util#_get_base_path() abort
  return g:dein#_base_path
endfunction
function! dein#util#_get_runtime_path() abort
  if g:dein#_runtime_path !=# ''
    return g:dein#_runtime_path
  endif

  let g:dein#_runtime_path = dein#util#_get_cache_path() .. '/.dein'
  call dein#util#_safe_mkdir(g:dein#_runtime_path)
  return g:dein#_runtime_path
endfunction
function! dein#util#_get_cache_path() abort
  if g:dein#_cache_path !=# ''
    return g:dein#_cache_path
  endif

  const vimrc_path = has('nvim') && exists('$NVIM_APPNAME') ?
        \ $NVIM_APPNAME :
        \ dein#util#_get_myvimrc()->fnamemodify(':t')
  let g:dein#_cache_path = dein#util#_substitute_path(
        \ g:->get('dein#cache_directory', g:dein#_base_path)
        \ .. '/.cache/' .. vimrc_path)
  call dein#util#_safe_mkdir(g:dein#_cache_path)
  return g:dein#_cache_path
endfunction
function! dein#util#_get_vimrcs(vimrcs) abort
  return !(a:vimrcs->empty()) ?
        \ dein#util#_convert2list(a:vimrcs)
        \ ->map({ _, val -> dein#util#_substitute_path(val->expand()) }) :
        \ [dein#util#_get_myvimrc()]
endfunction
function! dein#util#_get_myvimrc() abort
  const vimrc = $MYVIMRC !=# '' ? $MYVIMRC :
        \ 'scriptnames'->execute()->split('\n')[0]
        \  ->matchstr('^\s*\d\+:\s\zs.*')
  return dein#util#_substitute_path(vimrc)
endfunction

function! dein#util#_error(msg) abort
  for mes in s:msg2list(a:msg)
    echohl WarningMsg | echomsg '[dein] ' .. mes | echohl None
  endfor
endfunction
function! dein#util#_notify(msg) abort
  call dein#util#_set_default(
        \ 'g:dein#enable_notification', v:false)
  call dein#util#_set_default(
        \ 'g:dein#notification_icon', '')
  call dein#util#_set_default(
        \ 'g:dein#notification_time', 2000)

  if !g:dein#enable_notification || a:msg ==# ''
    call dein#util#_error(a:msg)
    return
  endif

  const title = '[dein]'

  if has('nvim')
    if dein#util#_luacheck('notify')
      " Use nvim-notify plugin
      call luaeval('require("notify")(_A.msg, "info", {'.
            \ 'timeout=vim.g["dein#notification_time"],'.
            \ 'title=_A.title })',
            \ #{ msg: a:msg, title: title })
    else
      call nvim_notify(a:msg, -1, #{ title: title })
    endif
  else
    if dein#is_available('vim-notification')
          \ || 'g:loaded_notification'->exists()
      " Use vim-notification plugin
      call notification#show(#{
            \   text: a:msg,
            \   title: title,
            \   wait: g:dein#notification_time,
            \ })
    else
      call popup_notification(a:msg, #{
            \   title: title,
            \   time: g:dein#notification_time,
            \ })
    endif
  endif
endfunction
function! dein#util#_luacheck(module) abort
  return has('nvim') && luaeval(
        \ 'type(select(2, pcall(require, _A.module))) == "table"',
        \ #{ module: a:module })
endfunction


function! dein#util#_chomp(str) abort
  return a:str !=# '' && a:str[-1:] ==# '/' ? a:str[: -2] : a:str
endfunction

function! dein#util#_uniq(list) abort
  let list = a:list->copy()
  let i = 0
  let seen = {}
  while i < list->len()
    let key = list[i]
    if key !=# '' && seen->has_key(key)
      call remove(list, i)
    else
      if key !=# ''
        let seen[key] = 1
      endif
      let i += 1
    endif
  endwhile
  return list
endfunction

function! dein#util#_is_fish() abort
  return dein#install#_is_async() && &shell->fnamemodify(':t:r') ==# 'fish'
endfunction
function! dein#util#_is_powershell() abort
  return dein#install#_is_async()
        \ && &shell->fnamemodify(':t:r') =~? 'powershell\|pwsh'
endfunction

function! dein#util#_check_lazy_plugins() abort
  return dein#util#_get_lazy_plugins()->filter({ _, val ->
        \    val.rtp->isdirectory()
        \    && !(val->get('local', 0))
        \    && val->get('hook_source', '') ==# ''
        \    && val->get('hook_add', '') ==# ''
        \    && !((val.rtp .. '/plugin')->isdirectory())
        \    && !((val.rtp .. '/after/plugin')->isdirectory())
        \ })->map({ _, val -> val.name })
endfunction
function! dein#util#_check_clean() abort
  const plugins_directories = dein#get()->values()
        \ ->map({ _, val -> val.path })
  const path = dein#util#_substitute_path(
        \ 'repos/*/*/*'->globpath(dein#util#_get_base_path(), v:true))
  return path->split("\n")->filter( { _, val ->
        \  val->isdirectory() && val->fnamemodify(':t') !=# 'dein.vim'
        \  && plugins_directories->index(val) < 0
        \ })
endfunction

function! dein#util#_cache_writefile(list, path) abort
  if !(dein#util#_get_cache_path()->filewritable())
    return 1
  endif

  const path = dein#util#_get_cache_path() .. '/' .. a:path
  return dein#util#_safe_writefile(a:list, path)
endfunction
function! dein#util#_safe_writefile(list, path, flags = '') abort
  if g:dein#_is_sudo
    return 1
  endif

  call dein#util#_safe_mkdir(fnamemodify(a:path, ':h'))
  return writefile(a:list, a:path, a:flags)
endfunction
function! dein#util#_safe_mkdir(path) abort
  if g:dein#_is_sudo || a:path->isdirectory()
    return 1
  endif
  return mkdir(a:path, 'p')
endfunction

function! dein#util#_get_type(name) abort
  return dein#parse#_get_types()->get(a:name, {})
endfunction

function! dein#util#_save_cache(vimrcs, is_state, is_starting) abort
  if dein#util#_get_cache_path() ==# '' || !a:is_starting
    " Ignore
    return 1
  endif

  let plugins = dein#get()->deepcopy()

  for plugin in plugins->values()
    if !a:is_state
      let plugin.sourced = 0
    endif
    if plugin->has_key('orig_opts')
      call remove(plugin, 'orig_opts')
    endif
    if plugin->has_key('called')
      call remove(plugin, 'called')
    endif

    " Hooks
    for hook in [
          \ 'hook_add', 'hook_source',
          \ 'hook_post_source', 'hook_post_update', 'hook_done_update',
          \ ]->filter({ _, val -> plugin->has_key(val)
          \      && plugin[val]->type() == v:t_func })
      let name = plugin[hook]->get('name')
      if name =~# '^<lambda>'
        call remove(plugin, hook)
      else
        let plugin[hook] = #{
              \   name: name,
              \   args: plugin[hook]->get('args'),
              \ }
      endif
    endfor
  endfor

  call dein#util#_safe_mkdir(g:dein#_base_path)

  const src = [plugins, g:dein#ftplugin]
  call dein#util#_safe_writefile(
        \ has('nvim') ? [src->json_encode()] : [src->js_encode()],
        \ g:->get('dein#cache_directory', g:dein#_base_path)
        \ .'/cache_' .. g:dein#_progname)
endfunction
function! dein#util#_check_vimrcs() abort
  const time = dein#util#_get_runtime_path()->getftime()
  const ret = !(g:dein#_vimrcs->copy()
        \ ->map({ _, val -> val->expand()->getftime() })
        \ ->filter({ _, val -> time < val })->empty())
  if !ret
    return 0
  endif

  call dein#clear_state()

  return ret
endfunction

function! dein#util#_save_state(is_starting) abort
  if g:dein#_block_level != 0
    call dein#util#_error('Invalid dein#save_state() usage.')
    return 1
  endif

  if dein#util#_get_cache_path() ==# '' || !a:is_starting || g:dein#_is_sudo
    " Ignore
    return 1
  endif

  if g:->get('dein#auto_recache', v:false)
    call dein#util#_notify('auto recached')
    call dein#recache_runtimepath()
  endif

  let g:dein#_vimrcs = dein#util#_uniq(g:dein#_vimrcs)
  let &runtimepath = dein#util#_join_rtp(dein#util#_uniq(
        \ dein#util#_split_rtp(&runtimepath)), &runtimepath, '')

  call dein#util#_save_cache(g:dein#_vimrcs, 1, a:is_starting)

  " Version check

  let lines = [
        \ 'if g:dein#_cache_version !=# ' ..
        \     g:dein#_cache_version .. ' || ' ..
        \ 'g:dein#_init_runtimepath !=# ' ..
        \      g:dein#_init_runtimepath->string() ..
        \      ' | throw ''Cache loading error'' | endif',
        \ 'let [s:plugins, s:ftplugin] = dein#min#_load_cache_raw(' ..
        \      g:dein#_vimrcs->string() .. ')',
        \ "if s:plugins->empty() | throw 'Cache loading error' | endif",
        \ 'let g:dein#_plugins = s:plugins',
        \ 'let g:dein#ftplugin = s:ftplugin',
        \ 'let g:dein#_base_path = ' .. g:dein#_base_path->string(),
        \ 'let g:dein#_runtime_path = ' .. g:dein#_runtime_path->string(),
        \ 'let g:dein#_cache_path = ' .. g:dein#_cache_path->string(),
        \ 'let g:dein#_on_lua_plugins = ' .. g:dein#_on_lua_plugins->string(),
        \ 'let &runtimepath = ' .. &runtimepath->string(),
        \ ]

  if g:->get('dein#enable_hook_function_cache', v:false)
    let lines += [
          \ 'call map(g:dein#_plugins, {' ..
          \ 'k,v -> empty(map(filter(["hook_add", "hook_source",' ..
          \ '"hook_post_source", "hook_post_update", "hook_done_source"],' ..
          \ '{ _, h -> v->has_key(h)}),' ..
          \ '{ _, h -> v[h]->type() == v:t_dict ? ' ..
          \ ' execute("let v[h] = function(''".get(v[h], "name")' ..
          \ ' .."'',"..string(get(v[h], "args"))..")") : v:null' ..
          \ '})) ? v : v })'
          \ ]
  endif

  if g:dein#_off1 !=# ''
    call add(lines, g:dein#_off1)
  endif
  if g:dein#_off2 !=# ''
    call add(lines, g:dein#_off2)
  endif

  " Add dummy mappings/commands
  for plugin in dein#util#_get_lazy_plugins()
    for command in plugin->get('dummy_commands', [])
      call add(lines, 'silent! ' .. command[1])
    endfor
    for mapping in plugin->get('dummy_mappings', [])
      call add(lines, 'silent! ' .. mapping[2])
    endfor
  endfor

  " Add inline vimrcs
  for vimrc in g:->get('dein#inline_vimrcs', [])
    let lines += vimrc->readfile()
          \ ->filter({ _, val -> val !=# '' && val !~# '^\s*"' })
  endfor

  " Add hooks
  if !(g:dein#_hook_add->empty())
    let lines += s:skipempty(g:dein#_hook_add)
  endif
  for plugin in dein#util#_tsort(dein#get()->values())
        \ ->filter({ _, val ->
        \   val.path->isdirectory() &&
        \   (!(val->has_key('if')) || val.if->eval())
        \ })
    if plugin->has_key('hook_add') && plugin.hook_add->type() == v:t_string
      let lines += s:skipempty(plugin.hook_add)
    endif

    " Invalid hooks detection
    for key in plugin->copy()
          \ ->filter({ key, val ->
          \   key->stridx('hook_') == 0
          \   && val->type() == v:t_func
          \   && val->get('name') =~# '^<lambda>'})->keys()
        call dein#util#_error(
              \ printf('%s: "%s" cannot be lambda to save state',
              \        plugin.name, key))
    endfor
  endfor

  " Add events
  for [event, plugins] in g:dein#_event_plugins->items()
        \ ->filter({ _, val -> ('##' .. val[0])->exists() })
    call add(lines, printf('autocmd dein-events %s call '
          \ .. 'dein#autoload#_on_event("%s", %s)',
          \ (('##' .. event)->exists() ? event .. ' *' : 'User ' .. event),
          \ event, plugins->string()))
  endfor

  const state = g:->get('dein#cache_directory', g:dein#_base_path)
        \ .. '/state_' .. g:dein#_progname .. '.vim'
  call dein#util#_safe_writefile(lines, state)
endfunction
function! dein#util#_clear_state() abort
  const base = g:->get('dein#cache_directory', g:dein#_base_path)
  for cache in (base .. '/state_*.vim')->glob(v:true, v:true)
        \ + (base .. '/cache_*')->glob(v:true, v:true)
    call delete(cache)
  endfor
endfunction

function! dein#util#_begin(path, vimrcs) abort
  if !('#dein'->exists())
    call dein#min#_init()
  endif

  if a:path ==# '' || g:dein#_block_level != 0
    call dein#util#_error('Invalid begin/end block usage.')
    return 1
  endif

  let g:dein#_block_level += 1
  let g:dein#_base_path = dein#util#_expand(a:path)
  if g:dein#_base_path[-1:] ==# '/'
    let g:dein#_base_path = g:dein#_base_path[: -2]
  endif
  call dein#util#_get_runtime_path()
  call dein#util#_get_cache_path()
  let g:dein#_vimrcs = dein#util#_get_vimrcs(a:vimrcs)
  if 'g:dein#inline_vimrcs'->exists()
    let g:dein#_vimrcs += g:dein#inline_vimrcs
  endif
  let g:dein#_hook_add = ''

  if has('vim_starting')
    " Filetype off
    if (!has('nvim') && g:->get('did_load_filetypes', v:false))
          \ || (has('nvim') && !(g:->get('do_filetype_lua', v:false)))
      let g:dein#_off1 = 'filetype off'
      execute g:dein#_off1
    endif
    if 'b:did_indent'->exists() || 'b:did_ftplugin'->exists()
      let g:dein#_off2 = 'filetype plugin indent off'
      execute g:dein#_off2
    endif
  else
    execute 'set rtp-=' .. g:dein#_runtime_path->fnameescape()
    execute 'set rtp-=' .. (g:dein#_runtime_path .. '/after')->fnameescape()
  endif

  " Insert dein runtimepath to the head in 'runtimepath'.
  let rtps = dein#util#_split_rtp(&runtimepath)
  const idx = rtps->index(dein#util#_substitute_path($VIMRUNTIME))
  if idx < 0
    call dein#util#_error(printf(
          \ '%s is not contained in "runtimepath".', $VIMRUNTIME))
    call dein#util#_error('verbose set runtimepath?'->execute())
    return 1
  endif
  if a:path->fnamemodify(':t') ==# 'plugin'
        \ && rtps->index(a:path->fnamemodify(':h')) >= 0
    call dein#util#_error('You must not set the installation directory'
          \ .. ' under "&runtimepath/plugin"')
    return 1
  endif
  call insert(rtps, g:dein#_runtime_path, idx)
  call dein#util#_add_after(rtps, g:dein#_runtime_path.'/after')
  let &runtimepath = dein#util#_join_rtp(rtps,
        \ &runtimepath, g:dein#_runtime_path)

  for vimrc in g:->get('dein#inline_vimrcs', [])
    execute 'source' vimrc->fnameescape()
  endfor
endfunction
function! dein#util#_end() abort
  if g:dein#_block_level != 1
    call dein#util#_error('Invalid begin/end block usage.')
    return 1
  endif

  let g:dein#_block_level -= 1

  if !has('vim_starting')
    call dein#source(g:dein#_plugins->values()
          \ ->filter({ _, val ->
          \          !val.lazy && !val.sourced && val.rtp !=# '' }))
  endif

  " Add runtimepath
  let rtps = dein#util#_split_rtp(&runtimepath)
  const index = rtps->index(g:dein#_runtime_path)
  if index < 0
    call dein#util#_error(printf(
          \ '%s is not contained in "runtimepath".', $VIMRUNTIME))
    call dein#util#_error('verbose set runtimepath?'->execute())
    return 1
  endif

  let depends = []
  let sourced = has('vim_starting') &&
        \ (!('&loadplugins'->exists()) || &loadplugins)
  for plugin in g:dein#_plugins->values()
        \ ->filter({ _, val -> !(val->empty())
        \          && !val.lazy && !val.sourced && val.rtp !=# ''
        \          && (!(v:val->has_key('if')) || v:val.if->eval())
        \          && v:val.path->isdirectory()
        \ })

    " Load dependencies
    if plugin->has_key('depends')
      let depends += plugin.depends
    endif

    if !plugin.merged
      call insert(rtps, plugin.rtp, index)
      if (plugin.rtp .. '/after')->isdirectory()
        call dein#util#_add_after(rtps, plugin.rtp .. '/after')
      endif
    endif

    let plugin.sourced = sourced
  endfor
  let &runtimepath = dein#util#_join_rtp(rtps, &runtimepath, '')

  if !(depends->empty())
    call dein#source(depends)
  endif

  for multi in g:dein#_multiple_plugins->copy()
        \ ->filter({ _, val -> dein#is_available(val.plugins) })
    if multi->has_key('hook_add')
      let g:dein#_hook_add ..= "\n" .. multi.hook_add->substitute(
            \ '\n\s*\\', '', 'g')
    endif
  endfor

  if g:dein#_hook_add !=# ''
    call dein#util#_execute_hook({}, g:dein#_hook_add)
  endif

  for [event, plugins] in g:dein#_event_plugins->items()
        \ ->filter({ _, val -> ('##' .. val[0])->exists() })
    execute printf('autocmd dein-events %s call '
          \ .. 'dein#autoload#_on_event("%s", %s)',
          \ (('##' .. event)->exists() ? event .. ' *' : 'User ' .. event),
          \ event, plugins->string())
  endfor

  if !has('vim_starting')
    call dein#call_hook('add')
    call dein#call_hook('source')
    call dein#call_hook('post_source')
  endif
endfunction
function! dein#util#_config(arg, dict) abort
  const name = a:arg->type() == v:t_dict ?
        \   g:dein#name : a:arg
  let dict = a:arg->type() == v:t_dict ?
        \   a:arg : a:dict
  if !(g:dein#_plugins->has_key(name))
    call dein#util#_error('Invalid plugin name: ' .. name)
    return {}
  endif
  if g:dein#_plugins[name].sourced
    return {}
  endif

  let plugin = g:dein#_plugins[name]
  let options = extend(#{ repo: plugin.repo }, dict)
  return dein#parse#_add(options.repo, options, v:true)
endfunction

function! dein#util#_call_hook(hook_name, plugins = []) abort
  const hook = 'hook_' .. a:hook_name
  let plugins = dein#util#_tsort(dein#util#_get_plugins(a:plugins))
        \ ->filter({ _, val ->
        \    ((a:hook_name !=# 'source'
        \      && a:hook_name !=# 'post_source') || val.sourced)
        \    && val->has_key(hook) && val.path->isdirectory()
        \    && (!(val->has_key('if')) || val.if->eval())
        \ })
  for plugin in plugins
    call dein#util#_execute_hook(plugin, plugin[hook])
  endfor
endfunction
function! dein#util#_execute_hook(plugin, hook) abort
  " Skip twice call
  if !(a:plugin->has_key('called'))
    let a:plugin.called = {}
  endif
  if a:plugin.called->has_key(a:hook->string())
    return
  endif

  try
    let g:dein#plugin = a:plugin

    if a:hook->type() == v:t_string
      let cmds = a:hook->split('\n')
      if !(cmds->empty()) && cmds[0] =~# '^\s*vim9script' && exists(':vim9')
        vim9 call execute(cmds[1 : ], '')
      else
        call execute(cmds, '')
      endif
    else
      call call(a:hook, [])
    endif

    let a:plugin.called[string(a:hook)] = v:true
  catch
    call dein#util#_error(
          \ 'Error occurred while executing hook: '
          \ .. a:plugin->get('name', ''))
    call dein#util#_error(v:exception)
  endtry
endfunction
function! dein#util#_set_hook(plugins, hook_name, hook) abort
  let names = a:plugins->empty() ? dein#get()->keys() :
        \ dein#util#_convert2list(a:plugins)
  for name in names
    if !(g:dein#_plugins->has_key(name))
      call dein#util#_error(name .. ' is not found.')
      return 1
    endif
    let plugin = g:dein#_plugins[name]
    let plugin[a:hook_name] =
          \ a:hook->type() != v:t_string ? a:hook :
          \   a:hook->substitute('\n\s*\\\|\%(^\|\n\)\s*"[^\n]*', '', 'g')
    if a:hook_name ==# 'hook_add'
      call dein#util#_call_hook('add', plugin)
    endif
  endfor
endfunction

function! dein#util#_tsort(plugins) abort
  let sorted = []
  let mark = {}
  for target in a:plugins
    call s:tsort_impl(target, mark, sorted)
  endfor

  return sorted
endfunction

function! dein#util#_split_rtp(runtimepath) abort
  if a:runtimepath->stridx('\,') < 0
    let rtps = a:runtimepath->split(',')
  else
    const split = a:runtimepath->split('\\\@<!\%(\\\\\)*\zs,')
    let rtps = split
          \ ->map({ _, val -> val->substitute('\\\([\\,]\)', '\1', 'g') })
  endif
  return rtps->map({ _, val -> dein#util#_substitute_path(val) })
endfunction
function! dein#util#_join_rtp(list, runtimepath, rtp) abort
  return (a:runtimepath->stridx('\,') < 0 && a:rtp->stridx(',') < 0) ?
        \ a:list->join(',') : a:list->copy()
        \ ->map({ _, val -> s:escape(val) })->join(',')
endfunction

function! dein#util#_add_after(rtps, path) abort
  const idx = a:rtps->index(dein#util#_substitute_path($VIMRUNTIME))
  call insert(a:rtps, a:path, (idx <= 0 ? -1 : idx + 1))
endfunction

function! dein#util#_expand(path) abort
  const path = (a:path =~# '^\~') ? a:path->fnamemodify(':p') :
        \ (a:path =~# '^\$\h\w*') ? a:path
        \ ->substitute('^\$\h\w*', '\=eval(submatch(0))', '') :
        \ a:path
  return (s:is_windows && path =~# '\\') ?
        \ dein#util#_substitute_path(path) : path
endfunction
function! dein#util#_substitute_path(path) abort
  return ((s:is_windows || has('win32unix')) && a:path =~# '\\') ?
        \ a:path->tr('\', '/') : a:path
endfunction

function! dein#util#_convert2list(expr) abort
  return a:expr->type() ==# v:t_list ? a:expr->copy() :
        \ a:expr->type() ==# v:t_string ?
        \   (a:expr ==# '' ? [] : a:expr->split('\r\?\n', 1))
        \ : [a:expr]
endfunction
function! dein#util#_split(expr) abort
  return a:expr->type() ==# v:t_list ? a:expr->copy() :
        \ a:expr->split('\r\?\n')
endfunction

function! dein#util#_get_lazy_plugins() abort
  return g:dein#_plugins->values()
        \ ->filter({ _, val -> !val.sourced && val.rtp !=# '' })
endfunction

function! dein#util#_get_plugins(plugins) abort
  return a:plugins->empty() ?
        \ dein#get()->values() :
        \ dein#util#_convert2list(a:plugins)
        \ ->map({ _, val -> val->type() == v:t_dict ? val : dein#get(val) })
        \ ->filter({ _, val -> !(val->empty()) })
endfunction

function! dein#util#_disable(names) abort
  for plugin in dein#util#_convert2list(a:names)
        \ ->filter({ _, val ->
        \   g:dein#_plugins->has_key(val) && !g:dein#_plugins[val].sourced
        \ })->map( { _, val -> g:dein#_plugins[val]})
    if plugin->has_key('dummy_commands')
      for command in plugin.dummy_commands
        silent! execute 'delcommand' command[0]
      endfor
      let plugin.dummy_commands = []
    endif

    if plugin->has_key('dummy_mappings')
      for map in plugin.dummy_mappings
        silent! execute map[0].'unmap' map[1]
      endfor
      let plugin.dummy_mappings = []
    endif

    call remove(g:dein#_plugins, plugin.name)
  endfor
endfunction

function! dein#util#_download(uri, outpath) abort
  if !('g:dein#download_command'->exists())
    let g:dein#download_command =
          \ 'curl'->executable() ? 'curl --silent --location --output' :
          \ 'wget'->executable() ? 'wget -q -O' : ''
  endif
  if g:dein#download_command !=# ''
    return printf('%s "%s" "%s"',
          \ g:dein#download_command, a:outpath, a:uri)
  elseif dein#util#_is_windows()
    " Use powershell
    " Todo: Proxy support
    const pscmd = printf(
          \ "(New-Object Net.WebClient).DownloadFile('%s', '%s')",
          \ a:uri, a:outpath)
    return printf('powershell -Command "%s"', pscmd)
  else
    return 'E: curl or wget command is not available!'
  endif
endfunction

function! s:tsort_impl(target, mark, sorted) abort
  if a:target->empty() || a:mark->has_key(a:target.name)
    return
  endif

  let a:mark[a:target.name] = 1
  if a:target->has_key('depends')
    for depend in a:target.depends
      call s:tsort_impl(dein#get(depend), a:mark, a:sorted)
    endfor
  endif

  call add(a:sorted, a:target)
endfunction

function! dein#util#_check_install(plugins) abort
  if g:dein#_is_sudo
    return
  endif

  if !(a:plugins->empty())
    const invalids = dein#util#_convert2list(a:plugins)
          \ ->filter({ _, val -> dein#get(val)->empty() })
    if !(invalids->empty())
      call dein#util#_error('Invalid plugins: ' .. invalids->string())
      return -1
    endif
  endif
  let plugins = a:plugins->empty() ? dein#get()->values() :
        \ dein#util#_convert2list(a:plugins)
        \ ->map({ _, val -> dein#get(val) })
  let plugins = plugins->filter({ _, val -> !(val.path->isdirectory()) })
  if empty(plugins) | return 0 | endif
  call dein#util#_notify('Not installed plugins: ' ..
        \ plugins->map({ _, val -> val.name })->string())
  return 1
endfunction

function! s:msg2list(expr) abort
  return a:expr->type() ==# v:t_list ? a:expr : a:expr->split('\n')
endfunction
function! s:skipempty(string) abort
  return a:string->split('\n')->filter({ _, val -> val !=# '' })
endfunction

function! s:escape(path) abort
  " Escape a path for runtimepath.
  return a:path->substitute(',\|\\,\@=', '\\\0', 'g')
endfunction
function! dein#util#escape_match(str) abort
  return a:str->escape('~\.^$[]')
endfunction

function! s:neovim_version() abort
  return 'version'->execute()->matchstr('NVIM v\zs\d\.\d\.\d')->str2float()
endfunction
