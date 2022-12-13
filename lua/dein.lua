local call = vim.call

-- NOTE: empty_dict is needed.  {} does not work.
vim.cmd('let g:dein#_empty_dict = {}')
local empty_dict = vim.g['dein#_empty_dict']

local M = {}

M.load_state = function(path)
  return call('dein#load_state', path)
end

M.tap = function(name)
  return call('dein#tap', name)
end

M.is_sourced = function(name)
  return call('dein#is_sourced', name)
end

M.begin = function(path, vimrcs)
  vimrcs = vimrcs or {}
  return call('dein#begin', path, vimrcs)
end

M.end_ = function()
  return call('dein#end')
end

M.add = function(repo, opts)
  opts = opts or empty_dict
  return call('dein#add', repo, opts)
end

M.local_ = function(dir, opts)
  opts = opts or empty_dict
  return call('dein#local', dir, names)
end

M.get = function(name)
  name = name or ''
  return call('dein#get', plugins)
end

M.source = function(names)
  names = names or {}
  return call('dein#source', names)
end

M.check_install = function(plugins)
  plugins = plugins or {}
  return call('dein#check_install', plugins)
end

M.check_update = function(plugins)
  plugins = plugins or {}
  return call('dein#check_update', plugins)
end

M.check_clean = function(plugins)
  plugins = plugins or {}
  return call('dein#check_clean', plugins)
end

M.install = function(plugins)
  plugins = plugins or {}
  return call('dein#install', plugins)
end

M.update = function(plugins)
  plugins = plugins or {}
  return call('dein#update', plugins)
end

M.direct_install = function(plugins)
  plugins = plugins or {}
  return call('dein#direct_install', plugins)
end

M.get_direct_plugins_path = function()
  return call('dein#get_direct_plugins_path')
end

M.reinstall = function(plugins)
  return call('dein#reinstall', plugins)
end

M.rollback = function(plugins)
  return call('dein#rollback', plugins)
end

M.save_rollback = function(file, plugins)
  plugins = plugins or {}
  return call('dein#save_rollback', file, plugins)
end

M.load_rollback = function(file, plugins)
  plugins = plugins or {}
  return call('dein#load_rollback', file, plugins)
end

M.remote_plugins = function()
  return call('dein#remote_plugins')
end

M.recache_runtimepath = function()
  return call('dein#recache_runtimepath')
end

M.call_hook = function(name)
  return call('dein#call_hook')
end

M.check_lazy_plugins = function()
  return call('dein#check_lazy_plugins')
end

M.load_toml = function(filename, opts)
  opts = opts or empty_dict
  return call('dein#load_toml', filename, opts)
end

M.load_dict = function(filename, opts)
  opts = opts or empty_dict
  return call('dein#load_dict', filename, opts)
end

M.get_log = function()
  return call('dein#get_log')
end

M.get_updates_log = function()
  return call('dein#get_updates_log')
end

M.get_progress = function()
  return call('dein#get_progress')
end

M.get_failed_plugins = function()
  return call('dein#get_failed_plugins')
end

M.each = function(command, plugins)
  plugins = plugins or {}
  return call('dein#each', command, plugins)
end

M.build = function(plugins)
  plugins = plugins or {}
  return call('dein#build', plugins)
end

M.plugins2toml = function(plugins)
  plugins = plugins or {}
  return call('dein#plugins2toml', plugins)
end

M.disable = function(names)
  return call('dein#disable', names)
end

M.config = function(arg, opts)
  opts = opts or empty_dict
  return call('dein#config', arg, opts)
end

M.set_hook = function(plugins, hook_name, hook)
  return call('dein#set_hook', plugins, hook_name, hook)
end

M.save_state = function()
  return call('dein#save_state')
end

M.clear_state = function()
  return call('dein#clear_state')
end

M.deno_cache = function(plugins)
  plugins = plugins or {}
  return call('dein#deno_cache', plugins)
end

M.post_sync = function(plugins)
  plugins = plugins or {}
  return call('dein#post_sync', plugins)
end

M.get_updated_plugins = function(plugins)
  plugins = plugins or {}
  return call('dein#get_updated_plugins', plugins)
end

M.setup = function(opts)
  opts = opts or empty_dict
  return call('dein#options', opts)
end

return M
