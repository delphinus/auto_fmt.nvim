local Methods = require("vim.lsp.protocol").Methods

---@class AutoFmtInstance
---@field bufnr integer
---@field enabled boolean
---@field group? integer
---@field filter fun(client: vim.lsp.Client): boolean
---@field verbose boolean
local AutoFmtInstance = {}

---@class AutoFmtOptions
---@field filter? fun(client: vim.lsp.Client): boolean
---@field verbose boolean default: true

---@type AutoFmtOptions
local default_options = {
  filter = function(_)
    return true
  end,
  verbose = true,
}

---@param bufnr integer
---@param opts? AutoFmtOptions
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
  opts = vim.tbl_extend("force", default_options, opts or {}) --[[@as AutoFmtOptions]]
  local self = setmetatable(
    { bufnr = bufnr, enabled = true, filter = opts.filter, verbose = opts.verbose },
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
    buffer = self.bufnr,
    callback = function()
      if #vim.lsp.get_clients { bufnr = self.bufnr, method = Methods.textDocument_formatting } > 0 then
        vim.lsp.buf.format { filter = self.filter }
      end
    end,
  })
  if self.verbose then
    vim.notify(("[auto_fmt] enable auto formatting on buf: %d"):format(self.bufnr), vim.log.levels.DEBUG)
  end
end

function AutoFmtInstance:disable()
  if self.group then
    vim.api.nvim_clear_autocmds { group = self.group }
  end
  if self.verbose then
    vim.notify(("[auto_fmt] disable auto formatting on buf: %d"):format(self.bufnr), vim.log.levels.DEBUG)
  end
end

---@class AutoFmt
---@field private filter fun(client: vim.lsp.Client): boolean
---@field private group integer
---@field private instances AutoFmtInstance[]
---@field private verbose boolean
---@field private [integer] AutoFmtInstance
local AutoFmt = {}

---@param opts? AutoFmtOptions
---@return AutoFmt
AutoFmt.new = function(opts)
  opts = vim.tbl_extend("force", default_options, opts or {}) --@as AutoFmtOptions
  local self = setmetatable(
    { filter = opts.filter, instances = {}, verbose = opts.verbose },
    { __index = AutoFmt.__index }
  )
  vim.api.nvim_create_autocmd("BufRead", {
    group = vim.api.nvim_create_augroup("auto_fmt", {}),
    callback = function()
      self:on()
    end,
  })
  return self
end

---@param key string|integer
function AutoFmt:__index(key)
  if type(key) == "number" then
    return rawget(self, "instances")[key]
  end
  return rawget(self, key) or rawget(AutoFmt, key)
end

---@param bufnr? integer
---@return integer
local function bufnr_to_key(bufnr)
  return (not bufnr or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr --[[@as integer]]
end

---@param bufnr? integer
function AutoFmt:on(bufnr)
  local key = bufnr_to_key(bufnr)
  if self[key] then
    self[key]:disable()
  end
  if self.verbose then
    vim.notify(("[auto_fmt] creating instance for buf: %d"):format(key))
  end
  self[key] = AutoFmtInstance.new(key, { filter = self.filter, verbose = self.verbose })
end

---@param bufnr? integer
function AutoFmt:off(bufnr)
  local key = bufnr_to_key(bufnr)
  if self[key] then
    self[key]:disable()
    self[key] = nil
  end
end

---@param bufnr? integer
function AutoFmt:toggle(bufnr)
  local key = bufnr_to_key(bufnr)
  if self[key] then
    self:off(key)
  else
    self:on(key)
  end
end

---@return boolean
function AutoFmt:is_enabled(bufnr)
  local key = bufnr_to_key(bufnr)
  return self[key] and self[key].enabled or false
end

---@type AutoFmt?
local auto_fmt_obj

---@return AutoFmt
local function auto_fmt()
  if auto_fmt_obj then
    return auto_fmt_obj
  end
  error "[auto_fmt] call setup() before this"
end

return {
  ---@param opts? AutoFmtOptions
  setup = function(opts)
    auto_fmt_obj = AutoFmt.new(opts)
  end,
  ---@param bufnr? integer
  on = function(bufnr)
    auto_fmt():on(bufnr)
  end,
  ---@param bufnr? integer
  off = function(bufnr)
    auto_fmt():off(bufnr)
  end,
  ---@param bufnr? integer
  ---@return boolean
  is_enabled = function(bufnr)
    return auto_fmt():is_enabled(bufnr)
  end,
  ---@param bufnr? integer
  toggle = function(bufnr)
    auto_fmt():toggle(bufnr)
  end,
}
