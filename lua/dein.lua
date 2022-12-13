local call = vim.call

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
  vimrcs = vimrcs or []
  return call('dein#begin', path, vimrcs)
end

M.end = function()
  return call('dein#end')
end

M.add = function(repo, opts)
  opts = opts or {}
  return call('dein#add', repo, opts)
end

M.local = function(dir, opts)
  opts = opts or {}
  names = names or ['*']
  return call('dein#local', dir, names)
end

M.get = function(name)
  name = name or ''
  return call('dein#get', plugins)
end
