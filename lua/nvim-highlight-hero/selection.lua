--- Reading the text to highlight from the buffer: the word under the cursor,
--- or the current / most recent visual selection (characterwise, linewise or
--- blockwise). Multibyte-safe via `getregion()`, with a plain fallback for
--- Neovim builds that lack it.

local M = {}

--- The keyword under the cursor, or "" when the cursor is not on one.
---
--- `expand("<cword>")` returns the keyword under *or after* the cursor, so on
--- indentation or punctuation it grabs the next word on the line. Guard that by
--- requiring the character under the cursor to be a keyword character.
---@return string
function M.word_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.fn.col(".") -- 1-based byte column of the cursor
  if vim.fn.matchstr(line, "\\%" .. col .. "c\\k") == "" then
    return ""
  end
  return vim.fn.expand("<cword>")
end

local function has_getregion()
  return vim.fn.exists("*getregion") == 1
end

-- Approximate region reader for builds without getregion(). Handles linewise,
-- blockwise and single-/multi-line characterwise selections well enough; the
-- primary path is getregion().
---@return string[]|nil
function M._fallback_region(p1, p2, regtype)
  if p1[2] > p2[2] or (p1[2] == p2[2] and p1[3] > p2[3]) then
    p1, p2 = p2, p1
  end
  local srow, scol, erow, ecol = p1[2] - 1, p1[3] - 1, p2[2] - 1, p2[3]
  if regtype == "V" then
    return vim.api.nvim_buf_get_lines(0, srow, erow + 1, false)
  elseif regtype == "\22" then
    local left, right = math.min(p1[3], p2[3]) - 1, math.max(p1[3], p2[3])
    local out = {}
    for row = srow, erow do
      local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
      out[#out + 1] = line:sub(left + 1, right)
    end
    return out
  end
  local ok, text = pcall(vim.api.nvim_buf_get_text, 0, srow, scol, erow, ecol, {})
  return ok and text or nil
end

--- Current (or most recent) visual selection.
---@return { text: string, lines: string[], linewise: boolean, blockwise: boolean }|nil
function M.visual()
  local m = vim.fn.mode()
  local p1, p2, regtype
  if m == "v" or m == "V" or m == "\22" then
    p1, p2, regtype = vim.fn.getpos("v"), vim.fn.getpos("."), m
  else
    p1, p2, regtype = vim.fn.getpos("'<"), vim.fn.getpos("'>"), vim.fn.visualmode()
  end
  if regtype == "" then
    return nil
  end

  local lines
  if has_getregion() then
    lines = vim.fn.getregion(p1, p2, { type = regtype })
  else
    lines = M._fallback_region(p1, p2, regtype)
  end
  if not lines or #lines == 0 then
    return nil
  end

  return {
    lines = lines,
    text = table.concat(lines, "\n"),
    linewise = regtype == "V",
    blockwise = regtype == "\22",
  }
end

return M
