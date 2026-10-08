-- Neovim config inside the Vim Dojo container: stock Neovim plus the game.

-- The plugin lives under /opt so the data volume (~/.local) never hides it.
vim.opt.packpath:prepend("/opt/nvim-plugins")
vim.cmd("packadd! vim-dojo")

-- The container exists only for the game: leaving the menu quits Neovim.
require("dojo").setup({ quit_on_close = true })

vim.opt.mouse = "" -- keyboard only
vim.opt.swapfile = false
