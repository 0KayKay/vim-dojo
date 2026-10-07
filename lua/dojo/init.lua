-- Vim Dojo: learn Vim motions as a game. See SPEC.md.
local M = {}

function M.setup(opts)
  require("dojo.config").setup(opts)
end

function M.open()
  require("dojo.ui.hl").setup()
  require("dojo.progress").load()
  require("dojo.ui.menu").show()
end

-- back to the menu from anywhere (the play buffer maps :q here)
function M.menu()
  require("dojo.session").abort()
  require("dojo.ui.hl").setup()
  require("dojo.ui.menu").show()
end

return M
