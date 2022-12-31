local M = setmetatable({}, {
  __index = function(_, key)
    return function(...)
      -- NOTE: For keyword conflict like dein#end()
      if vim.endswith(key, '_') then
        key = key:sub(1, -2)
      elseif key == 'setup' then
        key = 'options'
      end

      local ret = vim.call('dein#' .. key, ...)

      -- NOTE: For boolean functions
      if type(ret) ~= 'table' and (vim.startswith(key, 'check_') or vim.startswith(key, 'is_')) then
        ret = ret ~= 0
      end

      return ret
    end
  end,
})

return M
