--- nvim-highlight-hero public API.
---
--- Highlight words, selections and whole lines into numbered groups, with a
--- merge-friendly mode that matches lines ignoring indentation. Call setup()
--- once to install the default keymaps, the :HH / :HHoff commands and the
--- highlight groups.

local config = require("nvim-highlight-hero.config")
local engine = require("nvim-highlight-hero.engine")

local M = {}

---@param opts table|nil
function M.setup(opts)
  config.setup(opts)
end

-- Programmatic API.
M.highlight = engine.highlight
M.off = engine.off
M.off_all = engine.off_all
M.off_last = engine.off_last

-- Command backends (also referenced by the :HH / :HHoff user commands).
M.cmd_hh = engine.cmd_hh
M.cmd_hhoff = engine.cmd_hhoff

return M
