--- Highlight group definitions with a colour-blind-safe palette.
---
--- The ten group colours are built on the Okabe-Ito qualitative palette, which
--- stays distinguishable under the common colour-vision deficiencies. They are
--- used as true background colours; the foreground is chosen automatically for
--- legible contrast, and a 256-colour fallback is computed for each. Dark and
--- light variants are derived from the same hues (the light variant is a pastel
--- tint) and picked from &background. Everything is overridable via setup().

local M = {}

M.group_prefix = "NvimHighlightHero"
M.auto_group = "NvimHighlightHeroAuto"

-- Okabe-Ito core (0-7) plus two luminance/hue-separated extras (8-9).
M.base = {
  [0] = "#E69F00", -- orange
  [1] = "#56B4E9", -- sky blue
  [2] = "#009E73", -- bluish green
  [3] = "#F0E442", -- yellow
  [4] = "#0072B2", -- blue
  [5] = "#D55E00", -- vermillion
  [6] = "#CC79A7", -- reddish purple
  [7] = "#C8CCD0", -- light grey (lifted luminance so it stays distinct from the purple under CVD)
  [8] = "#00B3B3", -- teal
  [9] = "#B266FF", -- violet
}

-- Fraction each colour is darkened toward black for a light background, so the
-- saturated hues deepen (and stay visible on white) instead of washing out.
M.light_darken = 0.28

M.auto_base = { dark = "#50566B", light = "#9AA3B2" }

-- The resolved palette after apply(): group -> { bg, fg, ctermbg, ctermfg }.
M.current = {}

---@param group integer
---@return string
function M.name(group)
  return M.group_prefix .. group
end

-- ---- colour maths (pure) ---------------------------------------------------

local function hex_to_rgb(hex)
  hex = hex:gsub("#", "")
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

local function rgb_to_hex(r, g, b)
  local function clamp(v)
    return math.max(0, math.min(255, math.floor(v + 0.5)))
  end
  return string.format("#%02X%02X%02X", clamp(r), clamp(g), clamp(b))
end

local function srgb_to_linear(c)
  c = c / 255
  if c <= 0.04045 then
    return c / 12.92
  end
  return ((c + 0.055) / 1.055) ^ 2.4
end

local function linear_to_srgb(c)
  c = math.max(0, math.min(1, c))
  if c <= 0.0031308 then
    return c * 12.92 * 255
  end
  return (1.055 * c ^ (1 / 2.4) - 0.055) * 255
end

--- WCAG relative luminance.
function M.luminance(hex)
  local r, g, b = hex_to_rgb(hex)
  return 0.2126 * srgb_to_linear(r) + 0.7152 * srgb_to_linear(g) + 0.0722 * srgb_to_linear(b)
end

--- WCAG contrast ratio between two colours (>= 1).
function M.contrast_ratio(h1, h2)
  local l1, l2 = M.luminance(h1), M.luminance(h2)
  if l1 < l2 then
    l1, l2 = l2, l1
  end
  return (l1 + 0.05) / (l2 + 0.05)
end

--- Black or white, whichever reads better on the given background.
function M.best_fg(bg)
  return M.contrast_ratio(bg, "#000000") >= M.contrast_ratio(bg, "#FFFFFF") and "#000000" or "#FFFFFF"
end

--- Blend a colour towards white by t in [0,1].
function M.blend_white(hex, t)
  local r, g, b = hex_to_rgb(hex)
  return rgb_to_hex(r + (255 - r) * t, g + (255 - g) * t, b + (255 - b) * t)
end

--- Blend a colour towards black by t in [0,1] (deepens hues for a light bg).
function M.blend_black(hex, t)
  local r, g, b = hex_to_rgb(hex)
  return rgb_to_hex(r * (1 - t), g * (1 - t), b * (1 - t))
end

--- Nearest xterm-256 index for a hex colour (6x6x6 cube or greyscale ramp).
function M.to_cterm(hex)
  local r, g, b = hex_to_rgb(hex)
  local levels = { 0, 95, 135, 175, 215, 255 }
  local function nearest6(v)
    local best, bi = math.huge, 0
    for i, l in ipairs(levels) do
      local d = math.abs(l - v)
      if d < best then
        best, bi = d, i - 1
      end
    end
    return bi
  end
  local ri, gi, bi = nearest6(r), nearest6(g), nearest6(b)
  local cr, cg, cb = levels[ri + 1], levels[gi + 1], levels[bi + 1]
  local dcube = (r - cr) ^ 2 + (g - cg) ^ 2 + (b - cb) ^ 2

  local gidx = math.max(0, math.min(23, math.floor(((r + g + b) / 3 - 8) / 10 + 0.5)))
  local gval = 8 + 10 * gidx
  local dgray = (r - gval) ^ 2 + (g - gval) ^ 2 + (b - gval) ^ 2

  if dgray < dcube then
    return 232 + gidx
  end
  return 16 + 36 * ri + 6 * gi + bi
end

--- Simulate deuteranopia (Machado 2009, severity 1.0). Returns the simulated
--- colour as a hex string - used by tests to check the palette stays distinct.
function M.simulate_deuteranopia(hex)
  local r, g, b = hex_to_rgb(hex)
  local lr, lg, lb = srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)
  local sr = 0.367322 * lr + 0.860646 * lg - 0.227968 * lb
  local sg = 0.280085 * lr + 0.672501 * lg + 0.047413 * lb
  local sb = -0.011820 * lr + 0.042940 * lg + 0.968881 * lb
  return rgb_to_hex(linear_to_srgb(sr), linear_to_srgb(sg), linear_to_srgb(sb))
end

--- Simulate protanopia (Machado 2009, severity 1.0).
function M.simulate_protanopia(hex)
  local r, g, b = hex_to_rgb(hex)
  local lr, lg, lb = srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)
  local sr = 0.152286 * lr + 1.052583 * lg - 0.204868 * lb
  local sg = 0.114503 * lr + 0.786281 * lg + 0.099216 * lb
  local sb = -0.003882 * lr - 0.048116 * lg + 1.051998 * lb
  return rgb_to_hex(linear_to_srgb(sr), linear_to_srgb(sg), linear_to_srgb(sb))
end

-- ---- applying the palette --------------------------------------------------

--- Resolve the background colour for a group given the current &background and
--- any user override.
local function resolve_bg(group, user, dark)
  if user and user[group] then
    return user[group]
  end
  if dark then
    return M.base[group]
  end
  return M.blend_black(M.base[group], M.light_darken)
end

--- Define all highlight groups. `user` may override per-group bg hex and `auto`.
---@param user table|nil
function M.apply(user)
  local dark = vim.o.background ~= "light"
  M.current = {}
  for group = 0, 9 do
    local bg = resolve_bg(group, user, dark)
    local fg = M.best_fg(bg)
    M.current[group] = { bg = bg, fg = fg, ctermbg = M.to_cterm(bg), ctermfg = M.to_cterm(fg) }
    vim.api.nvim_set_hl(0, M.name(group), {
      bg = bg,
      fg = fg,
      ctermbg = M.to_cterm(bg),
      ctermfg = M.to_cterm(fg),
      default = true,
    })
  end

  local abg = (user and user.auto) or (dark and M.auto_base.dark or M.auto_base.light)
  local afg = M.best_fg(abg)
  M.current.auto = { bg = abg, fg = afg, ctermbg = M.to_cterm(abg), ctermfg = M.to_cterm(afg) }
  vim.api.nvim_set_hl(0, M.auto_group, {
    bg = abg,
    fg = afg,
    ctermbg = M.to_cterm(abg),
    ctermfg = M.to_cterm(afg),
    bold = true,
    default = true,
  })
end

--- Open a scratch buffer previewing every group in the current background.
function M.preview()
  local ns = vim.api.nvim_create_namespace("NvimHighlightHeroPreview")
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = {
    ("nvim-highlight-hero palette  (%s background)"):format(vim.o.background),
    "",
  }
  for group = 0, 9 do
    lines[#lines + 1] = ("  group %d   %s   The quick brown fox jumps"):format(
      group,
      M.current[group] and M.current[group].bg or "?"
    )
  end
  lines[#lines + 1] = "  auto      the live current-word / selection highlight"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  for group = 0, 9 do
    local row = 2 + group
    vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { end_col = #lines[row + 1], hl_group = M.name(group) })
  end
  local arow = 12
  vim.api.nvim_buf_set_extmark(buf, ns, arow, 0, { end_col = #lines[arow + 1], hl_group = M.auto_group })

  vim.bo[buf].modifiable = false
  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, buf)
end

return M
