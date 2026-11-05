--- User-facing configuration: options, default keymaps, user commands and
--- autocmds. `setup()` is the single entry point.

local engine = require("nvim-highlight-hero.engine")
local colors = require("nvim-highlight-hero.colors")
local highlight = require("nvim-highlight-hero.highlight")
local auto = require("nvim-highlight-hero.auto")

local M = {}

M.defaults = {
  -- Digit maps are built as `prefix .. 0..9`, e.g. <leader>h3.
  prefix = "<leader>h",
  keymaps = {
    toggle_auto = "<leader>hh",
    toggle_auto_weak = "<leader>hH",
    off_last = "<leader>ho",
    off_all = "<leader>hO",
  },
  -- Set the default keymaps (digits + auto + off). Turn off to map it yourself.
  set_default_keymaps = true,
}

M.opts = vim.deepcopy(M.defaults)

function M.set_keymaps()
  local prefix = M.opts.prefix
  for g = 0, 9 do
    local lhs = prefix .. g
    vim.keymap.set("n", lhs, function()
      engine.highlight(g, "strong", { source = "word" })
    end, { silent = true, desc = ("Highlight word (group %d)"):format(g) })

    vim.keymap.set("x", lhs, function()
      engine.highlight(g, "strong", { source = "selection" })
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
    end, { silent = true, desc = ("Highlight selection (group %d)"):format(g) })
  end

  local km = M.opts.keymaps or {}
  if km.toggle_auto then
    vim.keymap.set({ "n", "x" }, km.toggle_auto, function()
      auto.toggle("strong")
    end, { silent = true, desc = "Toggle auto-highlight" })
  end
  if km.toggle_auto_weak then
    vim.keymap.set({ "n", "x" }, km.toggle_auto_weak, function()
      auto.toggle("weak")
    end, { silent = true, desc = "Toggle auto-highlight (weak)" })
  end
  if km.off_last then
    vim.keymap.set("n", km.off_last, function()
      engine.off_last()
    end, { silent = true, desc = "Clear last highlight group" })
  end
  if km.off_all then
    vim.keymap.set("n", km.off_all, function()
      engine.off_all()
    end, { silent = true, desc = "Clear all highlight groups" })
  end
end

function M.create_commands()
  vim.api.nvim_create_user_command("HH", function(a)
    engine.cmd_hh({ bang = a.bang, args = a.args, range = a.range })
  end, { bang = true, nargs = "?", range = true, desc = "Highlight into a group (! = weak match)" })

  vim.api.nvim_create_user_command("HHoff", function(a)
    engine.cmd_hhoff({ bang = a.bang, args = a.args })
  end, { bang = true, nargs = "?", desc = "Clear a highlight group (! = all)" })

  vim.api.nvim_create_user_command("HHauto", function(a)
    auto.toggle(a.bang and "weak" or "strong")
  end, { bang = true, desc = "Toggle live auto-highlight (! = weak)" })

  vim.api.nvim_create_user_command("HHcolors", function()
    colors.preview()
  end, { desc = "Preview the highlight palette" })
end

function M.create_autocmds()
  local grp = vim.api.nvim_create_augroup("NvimHighlightHero", { clear = true })

  -- Live auto-highlight: recompute on cursor movement and mode changes. The
  -- callback is a cheap no-op while auto-highlight is disabled.
  vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged" }, {
    group = grp,
    pattern = "*",
    callback = function()
      auto.update()
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = grp,
    pattern = "*",
    callback = function(ev)
      local win = tonumber(ev.match)
      if win then
        highlight.forget_window(win)
        auto.forget_window(win)
      end
    end,
  })

  -- Colorschemes often clear user highlight groups; reapply the palette after
  -- a colorscheme change or a dark/light background switch.
  vim.api.nvim_create_autocmd({ "ColorScheme", "OptionSet" }, {
    group = grp,
    pattern = "*",
    callback = function(ev)
      if ev.event == "OptionSet" and ev.match ~= "background" then
        return
      end
      colors.apply(M.opts.colors)
    end,
  })
end

---@param user_opts table|nil
function M.setup(user_opts)
  M.opts = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user_opts or {})
  colors.apply(M.opts.colors)
  if M.opts.set_default_keymaps then
    M.set_keymaps()
  end
  M.create_commands()
  M.create_autocmds()
end

return M
