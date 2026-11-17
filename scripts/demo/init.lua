-- Minimal, reproducible Neovim setup for recording the README demos
-- (scripts/demo/record.py). Only this plugin is loaded.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:prepend(root)

vim.g.mapleader = " "
vim.o.termguicolors = true
vim.o.background = "dark"
vim.o.number = true
vim.o.signcolumn = "no"
vim.o.laststatus = 0
vim.o.ruler = false
vim.o.showcmd = false
vim.o.swapfile = false
vim.o.hlsearch = false
vim.o.cursorline = false
vim.o.shortmess = vim.o.shortmess .. "I"
vim.o.fillchars = "eob: "
vim.cmd("syntax on")

-- Conflict markers stand out a little, like most merge setups show them.
vim.api.nvim_set_hl(0, "DemoConflictMarker", { fg = "#14161b", bg = "#8a8f98", bold = true })
vim.api.nvim_create_autocmd("BufWinEnter", {
  callback = function()
    vim.fn.matchadd("DemoConflictMarker", [[^\(<<<<<<<\|=======\|>>>>>>>\||||||||\)]], 5)
  end,
})

require("nvim-highlight-hero").setup({})
