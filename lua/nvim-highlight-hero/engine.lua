--- The engine ties the pure pattern builder, the selection reader and the
--- per-window highlight store together into the operations the commands and
--- keymaps call. No global match state lives here (it is per-window, in
--- highlight.lua).

local pattern = require("nvim-highlight-hero.pattern")
local selection = require("nvim-highlight-hero.selection")
local highlight = require("nvim-highlight-hero.highlight")
local colors = require("nvim-highlight-hero.colors")

local M = {}

--- Build the \V pattern for a given context.
---@param source "word"|"selection"
---@param preset table  pattern preset (boundaries/case)
---@param text_override string|nil  literal text supplied on the command line
---@return string|nil
local function build_for(source, preset, text_override)
  if text_override and text_override ~= "" then
    return pattern.build(text_override, {
      boundaries = preset.boundaries,
      case = preset.case,
      whitespace = "exact",
    })
  end

  if source == "selection" then
    local sel = selection.visual()
    if not sel then
      return nil
    end
    -- A selection matches literally; word boundaries never apply. Whitespace is
    -- "auto" so linewise / multi-line selections use merge matching.
    return pattern.build(sel.text, {
      boundaries = false,
      case = preset.case,
      whitespace = "auto",
      linewise = sel.linewise,
    })
  end

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

--- Highlight into a numbered group.
---@param group integer  0-9
---@param preset_name "strong"|"weak"
---@param opts { source?: "word"|"selection", text?: string, append?: boolean }|nil
function M.highlight(group, preset_name, opts)
  opts = opts or {}
  local preset = pattern.presets[preset_name] or pattern.presets.strong

  local source = opts.source
  if not source then
    local m = vim.fn.mode()
    source = (m == "v" or m == "V" or m == "\22") and "selection" or "word"
  end

  local pat = build_for(source, preset, opts.text)
  if not pat then
    return
  end

  local hl = colors.name(group)
  if opts.append then
    highlight.add(group, hl, pat)
  else
    highlight.toggle(group, hl, pat)
  end
end

--- Clear one group in the current window.
---@param group integer
function M.off(group)
  highlight.clear(group)
end

--- Clear every group in the current window.
function M.off_all()
  highlight.clear_all()
end

--- Clear the most recently set group in the current window.
function M.off_last()
  local g = highlight.last_group()
  if g ~= nil then
    highlight.clear(g)
  end
end

-- Parse a leading "[0-9]" group token off an argument string.
---@return integer group, string|nil text
local function parse_group_and_text(args)
  args = vim.trim(args or "")
  if args == "" then
    return 0, nil
  end
  local first, rest = args:match("^(%S+)%s*(.*)$")
  if first:match("^%d$") then
    return tonumber(first), (rest ~= "" and rest or nil)
  end
  return 0, args
end

--- `:HH[!] [N] [text]` - highlight into group N (default 0). `!` = weak preset.
--- With a range (visual `:'<,'>HH`) the selection is highlighted; otherwise the
--- word under the cursor (or the literal [text]).
---@param a { bang: boolean, args: string, range: integer }
function M.cmd_hh(a)
  local preset = a.bang and "weak" or "strong"
  local group, text = parse_group_and_text(a.args)
  local source = (a.range and a.range > 0) and "selection" or "word"
  M.highlight(group, preset, { source = source, text = text })
end

--- `:HHoff [N]` clears group N (or the last set group); `:HHoff!` clears all.
---@param a { bang: boolean, args: string }
function M.cmd_hhoff(a)
  if a.bang then
    M.off_all()
    return
  end
  local args = vim.trim(a.args or "")
  if args:match("^%d$") then
    M.off(tonumber(args))
  else
    M.off_last()
  end
end

return M
