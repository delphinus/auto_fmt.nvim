---@class AutoFmtInstance
---@field bufnr integer
---@field enabled boolean
---@field group? integer
---@field filter fun(client: vim.lsp.Client): boolean
local AutoFmtInstance = {}

---@class AutoFmtInstanceOptions
---@field enabled boolean
---@field filter fun(client: vim.lsp.Client): boolean

---@param bufnr integer
---@param opts? AutoFmtInstanceOptions
AutoFmtInstance.new = function(bufnr, opts)
  vim.validate {
    bufnr = {
      bufnr,
      function(v)
        return type(v) == "number" and v ~= 0
      end,
      "integer and not 0",
    },
  }
  ---@type AutoFmtInstanceOptions
  local default_options = {
    enabled = true,
    ---@param _ vim.lsp.Client
    ---@return boolean
    filter = function(_)
      return true
    end,
  }
  opts = vim.tbl_extend("force", default_options, opts or {}) --[[@as AutoFmtInstanceOptions]]
  local self = setmetatable(
    { bufnr = bufnr, enabled = opts.enabled, filter = opts.filter },
    { __index = AutoFmtInstance }
  )
  if self.enabled then
    self:enable()
  end
  return self
end

function AutoFmtInstance:enable()
  self.group = vim.api.nvim_create_augroup(("auto_fmt_%d"):format(self.bufnr), {})
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = self.group,
    callback = function()
      vim.lsp.buf.format { filter = self.filter }
    end,
  })
  vim.notify(("[auto_fmt] enable auto formatting on buf: %d"):format(self.bufnr), vim.log.levels.DEBUG)
end

function AutoFmtInstance:disable()
  if self.group then
    vim.api.nvim_clear_autocmds { group = self.group }
  end
  vim.notify(("[auto_fmt] disable auto formatting on buf: %d"):format(self.bufnr), vim.log.levels.DEBUG)
end

---@class AutoFmt
---@field private group integer
---@field private instances AutoFmtInstance[]
---@field private [integer] AutoFmtInstance
local AutoFmt = {}

---@return AutoFmt
AutoFmt.new = function()
  return setmetatable({ instances = {} }, { __index = AutoFmt.__index })
end

---@param key string|integer
function AutoFmt:__index(key)
  return type(key) == "number" and rawget(self, "instances")[key] or rawget(self, key) or rawget(AutoFmt, key)
end

---@param bufnr? integer
---@param opts? AutoFmtInstanceOptions
function AutoFmt:on(bufnr, opts)
  local key = self:bufnr(bufnr)
  if self[key] then
    self[key]:disable()
  end
  vim.notify(("[auto_fmt] creating instance for buf: %d"):format(key))
  self[key] = AutoFmtInstance.new(key, opts)
end

---@param bufnr? integer
function AutoFmt:off(bufnr)
  local key = self:bufnr(bufnr)
  if self[key] then
    self[key]:disable()
    self[key] = nil
  end
end

---@param bufnr? integer
function AutoFmt:toggle(bufnr)
  local key = self:bufnr(bufnr)
  if self[key] then
    self:off(key)
  else
    self:on(key)
  end
end

---@return boolean
function AutoFmt:is_enabled(bufnr)
  local key = self:bufnr(bufnr)
  return self[key] and self[key].enabled or false
end

---@private
---@param bufnr? integer
---@return integer
function AutoFmt:bufnr(bufnr)
  return not bufnr or bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr --[[@as integer]]
end

local auto_fmt = AutoFmt.new()

return {
  ---@param bufnr? integer
  ---@param opts? AutoFmtInstanceOptions
  on = function(bufnr, opts)
    auto_fmt:on(bufnr, opts)
  end,
  ---@param bufnr? integer
  off = function(bufnr)
    auto_fmt:off(bufnr)
  end,
  ---@param bufnr? integer
  toggle = function(bufnr)
    auto_fmt:toggle(bufnr)
  end,
}
