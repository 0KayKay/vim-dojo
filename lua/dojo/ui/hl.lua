-- Highlight groups. All are `default`, so a colorscheme or user can override.
local M = {}

local function link(name, target)
  vim.api.nvim_set_hl(0, name, { link = target, default = true })
end

local function set(name, spec)
  spec.default = true
  vim.api.nvim_set_hl(0, name, spec)
end

function M.setup()
  link("DojoTitle", "Title")
  link("DojoWorld", "Statement")
  link("DojoDim", "Comment")
  link("DojoGhost", "Comment")
  link("DojoKey", "Special")
  link("DojoStar", "DiagnosticWarn")
  link("DojoOk", "DiagnosticOk")
  link("DojoBad", "DiagnosticError")
  link("DojoWarn", "DiagnosticWarn")
  link("DojoLocked", "Comment")
  set("DojoTarget", { fg = "#1d1d1d", bg = "#f2c94c", ctermfg = 0, ctermbg = 11, bold = true })
  set("DojoDelete", { fg = "#ff7b72", ctermfg = 9, bold = true, strikethrough = true })
  set("DojoGoal", { fg = "#7ee787", ctermfg = 10, bold = true })
end

return M
