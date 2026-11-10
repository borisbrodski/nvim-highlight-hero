--- Pure pattern-building for nvim-highlight-hero.
---
--- This module has NO dependency on the Neovim API: it turns literal text plus
--- a small set of options into a Vim very-nomagic (`\V`) search pattern string.
--- Keeping it pure makes the trickiest logic (escaping, word boundaries, case
--- policy and whitespace/"merge" matching) fully unit-testable.
---
--- Options (all optional):
---   boundaries : boolean      wrap a single-line match in \< ... \> (whole word)
---   case       : "sensitive" | "insensitive" | "smart"   (default "smart")
---   whitespace : "exact" | "merge" | "flex" | "auto"     (default "auto")
---                "merge"  ignores leading indentation and trailing whitespace
---                         on every line and tolerates blank lines - used for
---                         comparing whole lines across a merge conflict.
---                "flex"   for a multi-line span that starts and/or ends
---                         mid-line: every line break (with the indentation
---                         and trailing whitespace around it) matches any run
---                         of whitespace, so the span also matches when it is
---                         indented differently or joined onto one line.
---                "auto"   = "merge" for linewise input, "flex" for other
---                         multi-line input, else "exact".
---
--- Presets map the classic strong/weak behaviour onto these flags.

local M = {}

M.presets = {
  -- `:HH`  - whole word, smartcase.
  strong = { boundaries = true, case = "smart", whitespace = "auto" },
  -- `:HH!` - substring, case-insensitive.
  weak = { boundaries = false, case = "insensitive", whitespace = "auto" },
}

--- Escape a literal string for use inside a `\V` pattern.
--- In very-nomagic mode the backslash is the only special character, so a
--- literal match only needs every backslash doubled. Everything else - dots,
--- stars, parentheses, quotes - is already literal.
---@param text string
---@return string
function M.escape_literal(text)
  return (text:gsub("\\", "\\\\"))
end

--- Split on newlines, preserving empty fields (blank lines and a leading or
--- trailing empty line). Unlike `gmatch("[^\n]+")` this never drops blank lines.
---@param text string
---@return string[]
function M.split_lines(text)
  local lines = {}
  local start = 1
  while true do
    local nl = text:find("\n", start, true)
    if not nl then
      lines[#lines + 1] = text:sub(start)
      break
    end
    lines[#lines + 1] = text:sub(start, nl - 1)
    start = nl + 1
  end
  return lines
end

--- Choose the Vim case atom. "smart" mirrors 'smartcase': case-insensitive
--- unless the text contains an uppercase letter.
---@param case string|nil
---@param text string
---@return string  "\\c" or "\\C"
function M.case_atom(case, text)
  if case == "insensitive" then
    return "\\c"
  elseif case == "sensitive" then
    return "\\C"
  end
  -- "smart" / default
  return text:match("%u") and "\\C" or "\\c"
end

local function strip(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Build the body for whitespace="merge": each line is reduced to its trimmed
--- core and matched ignoring indentation and trailing whitespace. Lines are
--- anchored to line boundaries so a core matches a whole line (not a substring
--- mid-line), while blank lines are preserved.
---@param lines string[]
---@return string
local function build_merge(lines)
  local parts = {}
  for _, line in ipairs(lines) do
    parts[#parts + 1] = M.escape_literal(strip(line))
  end
  -- `\_^` / `\_$` are the "start/end of any line" anchors (valid mid-pattern,
  -- unlike plain ^ / $); `\s\*` absorbs indentation and trailing whitespace;
  -- `\n` separates the lines.
  return "\\_^\\s\\*" .. table.concat(parts, "\\s\\*\\n\\s\\*") .. "\\s\\*\\_$"
end

local function is_word_byte(c)
  return c:match("[%w_\128-\255]") ~= nil
end

--- Build the body for whitespace="flex": the span is not tied to line
--- boundaries (a characterwise selection may start and end mid-line). Each
--- line break, together with the whitespace around it, becomes "any run of
--- whitespace, line breaks included". The run is mandatory between two word
--- characters (so words never fuse) and optional next to punctuation, so
--- `foo(\n    a` also matches `foo(a`. Whitespace at the very start and end of
--- the span and blank lines inside it are ignored.
---@param lines string[]
---@return string|nil  nil when the span holds nothing but whitespace
local function build_flex(lines)
  local cores = {}
  for _, line in ipairs(lines) do
    local core = strip(line)
    if core ~= "" then
      cores[#cores + 1] = core
    end
  end
  if #cores == 0 then
    return nil
  end
  local body = M.escape_literal(cores[1])
  for i = 2, #cores do
    local need_gap = is_word_byte(cores[i - 1]:sub(-1)) and is_word_byte(cores[i]:sub(1, 1))
    body = body .. (need_gap and "\\_s\\+" or "\\_s\\*") .. M.escape_literal(cores[i])
  end
  return body
end

--- Build the body for whitespace="exact": literal text, newlines as `\n`.
---@param lines string[]
---@return string
local function build_exact(lines)
  local parts = {}
  for _, line in ipairs(lines) do
    parts[#parts + 1] = M.escape_literal(line)
  end
  return table.concat(parts, "\\n")
end

--- Build a `\V` pattern from literal text and options.
---@param text string
---@param opts table|nil
---@return string
function M.build(text, opts)
  opts = opts or {}

  -- A single trailing newline is a selection artifact (linewise yanks include
  -- it); it marks the input as linewise but is not a blank line to match.
  local linewise = opts.linewise
  if text:sub(-1) == "\n" then
    linewise = true
    text = text:sub(1, -2)
  end

  local lines = M.split_lines(text)
  local multiline = #lines > 1

  local ws = opts.whitespace or "auto"
  if ws == "auto" then
    ws = linewise and "merge" or (multiline and "flex" or "exact")
  end

  local body
  if ws == "merge" then
    body = build_merge(lines)
  elseif ws == "flex" then
    body = build_flex(lines) or build_exact(lines)
  else
    body = build_exact(lines)
    -- Word boundaries only make sense for a single-line exact match.
    if opts.boundaries and not multiline then
      body = "\\<" .. body .. "\\>"
    end
  end

  return "\\V" .. M.case_atom(opts.case, text) .. body
end

--- Convenience: build from a preset name ("strong" | "weak"), merging any
--- extra option overrides.
---@param text string
---@param preset_name string
---@param overrides table|nil
---@return string
function M.build_preset(text, preset_name, overrides)
  local preset = M.presets[preset_name]
  assert(preset, "unknown preset: " .. tostring(preset_name))
  local opts = {}
  for k, v in pairs(preset) do
    opts[k] = v
  end
  if overrides then
    for k, v in pairs(overrides) do
      opts[k] = v
    end
  end
  return M.build(text, opts)
end

return M
