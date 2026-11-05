--- Per-window match bookkeeping. `matchadd()` matches are window-scoped, so
--- state is keyed by window id (fixing the old module-global toggle state that
--- leaked across windows and buffers). Each group tracks its match ids and, for
--- non-appended matches, the pattern that produced them so it can be toggled.

local M = {}

M.priority = 10

-- state[winid][group] = { ids = { match_id, ... }, pattern = string|nil }
local state = {}

local function win_state(win)
  win = (win and win ~= 0) and win or vim.api.nvim_get_current_win()
  state[win] = state[win] or {}
  return state[win], win
end

--- Remove a group's matches in the given (default current) window.
---@param group integer|string
---@param win integer|nil
function M.clear(group, win)
  local ws, w = win_state(win)
  local e = ws[group]
  if e then
    for _, id in ipairs(e.ids) do
      pcall(vim.fn.matchdelete, id, w)
    end
  end
  ws[group] = nil
end

--- Remove every group's matches in the window.
---@param win integer|nil
function M.clear_all(win)
  local ws, w = win_state(win)
  for group in pairs(ws) do
    M.clear(group, w)
  end
end

--- Append a match to a group. `pattern` here is the raw \V pattern; the group's
--- toggle pattern is cleared because an appended group is no longer a single
--- toggleable pattern.
---@return integer match_id
function M.add(group, hl_group, pattern, win)
  local ws, w = win_state(win)
  local id = vim.fn.matchadd(hl_group, pattern, M.priority, -1, { window = w })
  local e = ws[group] or { ids = {} }
  table.insert(e.ids, id)
  e.pattern = nil
  ws[group] = e
  return id
end

--- Replace a group's matches with a single pattern (remembered for toggling).
---@return integer match_id
function M.set(group, hl_group, pattern, win)
  local _, w = win_state(win)
  M.clear(group, w)
  local id = M.add(group, hl_group, pattern, w)
  win_state(w)[group].pattern = pattern
  return id
end

--- Toggle: clear the group if it already shows exactly this pattern, else set
--- it. Returns "on" or "off".
---@return "on"|"off"
function M.toggle(group, hl_group, pattern, win)
  local ws, w = win_state(win)
  local e = ws[group]
  if e and e.pattern == pattern then
    M.clear(group, w)
    return "off"
  end
  M.set(group, hl_group, pattern, w)
  return "on"
end

---@return boolean
function M.is_set(group, win)
  local ws = win_state(win)
  local e = ws[group]
  return e ~= nil and #e.ids > 0
end

--- Groups currently active in the window, sorted.
---@param win integer|nil
---@return (integer|string)[]
function M.active_groups(win)
  local ws = win_state(win)
  local out = {}
  for g in pairs(ws) do
    out[#out + 1] = g
  end
  table.sort(out)
  return out
end

--- Drop stored state for a window (e.g. on WinClosed). Matches themselves die
--- with the window.
---@param win integer
function M.forget_window(win)
  state[win] = nil
end

return M
