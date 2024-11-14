function! dein#load_cache_raw(vimrcs) abort
  return dein#min#_load_cache_raw(a:vimrcs)
endfunction
function! dein#load_state(path) abort
  return dein#min#load_state(a:path)
endfunction
function! dein#tap(name) abort
  if !dein#is_available(a:name) | return 0 | endif
  let g:dein#name = a:name
  let g:dein#plugin = g:dein#_plugins[a:name]
  return 1
endfunction
function! dein#is_sourced(name) abort
  return g:dein#_plugins->has_key(a:name) && g:dein#_plugins[a:name].sourced
endfunction
function! dein#is_available(names) abort
  for name in type(a:names) ==# v:t_list ? a:names : [a:names]
    if !(g:dein#_plugins->has_key(name)) | return 0 | endif
    let plugin = g:dein#_plugins[name]
    if !(plugin.path->isdirectory()) || (plugin->has_key('if')
          \ && !(plugin.if->eval())) | return 0 | endif
  endfor
  return 1
endfunction
function! dein#begin(path, vimrcs = []) abort
  return dein#util#_begin(a:path, a:vimrcs)
endfunction
function! dein#end() abort
  return dein#util#_end()
endfunction
function! dein#add(repo, options = {}) abort
  return dein#parse#_add(a:repo, a:options, v:false)
endfunction
function! dein#local(dir, options = {}, names = ['*']) abort
  return dein#parse#_local(a:dir, a:options, a:names)
endfunction
function! dein#get(name = '') abort
  return a:name ==# '' ?
        \ g:dein#_plugins->copy() : g:dein#_plugins->get(a:name, {})
endfunction
function! dein#source(plugins = g:dein#_plugins->values()) abort
  return dein#autoload#_source(a:plugins)
endfunction
function! dein#check_install(plugins = []) abort
  return dein#util#_check_install(a:plugins)
endfunction
function! dein#check_update(force = v:false, plugins = []) abort
  return dein#install#_check_update(a:plugins, a:force,
        \ dein#install#_is_async())
endfunction
function! dein#check_clean() abort
  return dein#util#_check_clean()
endfunction
function! dein#install(plugins = []) abort
  return dein#install#_do(a:plugins, 'install', dein#install#_is_async())
endfunction
function! dein#update(plugins = []) abort
  return dein#install#_do(a:plugins, 'update', dein#install#_is_async())
endfunction
function! dein#direct_install(repo, options = {}) abort
  call dein#install#_direct_install(a:repo, a:options)
endfunction
function! dein#get_direct_plugins_path() abort
  return dein#util#_get_cache_path()
        \ .'/direct_install.vim'
endfunction
function! dein#reinstall(plugins) abort
  call dein#install#_reinstall(a:plugins)
endfunction
function! dein#rollback(date, plugins = []) abort
  call dein#install#_rollback(a:date, a:plugins)
endfunction
function! dein#save_rollback(rollbackfile, plugins = []) abort
  call dein#install#_save_rollback(a:rollbackfile, a:plugins)
endfunction
function! dein#load_rollback(rollbackfile, plugins = []) abort
  call dein#install#_load_rollback(a:rollbackfile, a:plugins)
endfunction
function! dein#remote_plugins() abort
  return dein#install#_remote_plugins()
endfunction
function! dein#recache_runtimepath() abort
  call dein#install#_recache_runtimepath()
endfunction
function! dein#call_hook(hook_name, plugins = []) abort
  return dein#util#_call_hook(a:hook_name, a:plugins)
endfunction
function! dein#check_lazy_plugins() abort
  return dein#util#_check_lazy_plugins()
endfunction
function! dein#load_toml(filename, options = {}) abort
  return dein#parse#_load_toml(a:filename, a:options)
endfunction
function! dein#load_dict(dict, options = {}) abort
  return dein#parse#_load_dict(a:dict, a:options)
endfunction
function! dein#get_log() abort
  return dein#install#_get_log()->join("\n")
endfunction
function! dein#get_updates_log() abort
  return dein#install#_get_updates_log()->join("\n")
endfunction
function! dein#get_progress() abort
  return dein#install#_get_progress()
endfunction
function! dein#get_failed_plugins() abort
  return dein#install#_get_failed_plugins()
endfunction
function! dein#each(command, plugins = []) abort
  return dein#install#_each(a:command, a:plugins)
endfunction
function! dein#build(plugins = []) abort
  return dein#install#_build(a:plugins)
endfunction
function! dein#plugins2toml(plugins) abort
  return dein#parse#_plugins2toml(a:plugins)
endfunction
function! dein#disable(names) abort
  return dein#util#_disable(a:names)
endfunction
function! dein#config(arg, options = {}) abort
  return a:arg->type() == v:t_dict ? dein#util#_config(g:dein#name, a:arg) :
        \ a:arg->type() != v:t_list ? dein#util#_config(a:arg, a:options) :
        \ a:arg->copy()->map({ _, val -> dein#util#_config(val, a:options) })
endfunction
function! dein#set_hook(plugins, hook_name, hook) abort
  return dein#util#_set_hook(a:plugins, a:hook_name, a:hook)
endfunction
function! dein#save_state() abort
  return dein#util#_save_state(has('vim_starting'))
endfunction
function! dein#clear_state() abort
  call dein#util#_clear_state()
  if !(g:->get('dein#auto_recache', v:false)) && !(g:dein#ftplugin->empty())
    call dein#util#_notify(
          \ 'call dein#recache_runtimepath() is needed for ftplugin')
  endif
endfunction
function! dein#deno_cache(plugins = []) abort
  call dein#install#_deno_cache(a:plugins)
endfunction
function! dein#post_sync(plugins) abort
  call dein#install#_post_sync(a:plugins)
endfunction
function! dein#get_updated_plugins(plugins = []) abort
  return dein#install#_get_updated_plugins(
        \ a:plugins, dein#install#_is_async())
endfunction
function! dein#options(options) abort
  for [key, val] in a:options->items()
    let g:dein#{key} = val
  endfor
endfunction
