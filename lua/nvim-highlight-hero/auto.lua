--- Live auto-highlight: continuously highlight the word under the cursor (in
--- normal mode) or the current visual selection (in visual mode), updating as
--- the cursor or selection moves. For a linewise / multi-line visual selection
--- the merge whitespace mode is used, so selecting lines across a merge
--- conflict lights up every indentation-variant of them - the headline merge
--- workflow. Uses the dedicated NvimHighlightHeroAuto group, independent of the
--- numbered groups, and is tracked per window.

local pattern = require("nvim-highlight-hero.pattern")
local selection = require("nvim-highlight-hero.selection")
local colors = require("nvim-highlight-hero.colors")

local M = {}

M.enabled = false
M.preset = "strong"
M.priority = 9

local match = {} -- winid -> match id
local last = {} -- winid -> last applied pattern

local function clear_win(win)
  local id = match[win]
  if id then
    pcall(vim.fn.matchdelete, id, win)
  end
  match[win] = nil
  last[win] = nil
end

--- The pattern for the current context, or nil when there is nothing to show.
---@return string|nil
local function current_pattern()
  local preset = pattern.presets[M.preset] or pattern.presets.strong
  local m = vim.fn.mode()
  if m == "v" or m == "V" or m == "\22" then
    local sel = selection.visual()
    if not sel or sel.text == "" then
      return nil
    end
    return pattern.build(sel.text, {
      boundaries = false,
      case = preset.case,
      whitespace = "auto",
      linewise = sel.linewise,
    })
  elseif m == "n" then
    local word = selection.word_under_cursor()
    if word == "" then
      return nil
    end
    return pattern.build(word, {
      boundaries = preset.boundaries,
      case = preset.case,
      whitespace = "exact",
    })
  end
  return nil
end

--- Recompute and apply the auto-highlight for the current window. Cheap no-op
--- when disabled, so it is safe to call from CursorMoved/ModeChanged.
function M.update()
  if not M.enabled then
    return
  end
  local win = vim.api.nvim_get_current_win()
  local pat = current_pattern()
  if not pat then
    clear_win(win)
    return
  end
  if last[win] == pat then
    return
  end
  clear_win(win)
  match[win] = vim.fn.matchadd(colors.auto_group, pat, M.priority, -1, { window = win })
  last[win] = pat
end

--- Remove the auto-highlight from every window.
function M.clear_all()
  for win in pairs(match) do
    clear_win(win)
  end
end

function M.enable(preset_name)
  if preset_name then
    M.preset = preset_name
  end
  M.enabled = true
  M.update()
end

function M.disable()
  M.enabled = false
  M.clear_all()
end

--- Toggle with a preset. Enabling with a different preset while already on
--- switches the preset instead of turning off.
---@param preset_name "strong"|"weak"|nil
---@return boolean enabled
function M.toggle(preset_name)
  preset_name = preset_name or M.preset
  if M.enabled and M.preset == preset_name then
    M.disable()
    return false
  end
  M.preset = preset_name
  M.enabled = true
  M.update()
  return true
end

--- Drop per-window state (e.g. on WinClosed).
---@param win integer
function M.forget_window(win)
  clear_win(win)
end

return M
