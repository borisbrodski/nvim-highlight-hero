-- Minimal init for headless test runs. Puts the plugin and plenary on the
-- runtimepath. PLENARY_DIR lets CI/local runs point at a checkout of plenary.
vim.opt.rtp:append(".")
vim.opt.rtp:append(os.getenv("PLENARY_DIR") or "./.tests/plenary.nvim")
vim.cmd("runtime plugin/plenary.vim")
