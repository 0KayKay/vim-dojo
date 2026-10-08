if vim.g.loaded_dojo then
  return
end
vim.g.loaded_dojo = true

vim.api.nvim_create_user_command("Dojo", function()
  require("dojo").open()
end, { desc = "Open Vim Dojo" })

vim.api.nvim_create_user_command("DojoMenu", function()
  require("dojo").menu()
end, { desc = "Back to the Vim Dojo menu" })
