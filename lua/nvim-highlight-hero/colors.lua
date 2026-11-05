--- Highlight group definitions.
---
--- Phase 1 placeholder: link the plugin's groups to stock UI groups so matches
--- are visible immediately. Phase 3 replaces `palette`/`apply` with a curated,
--- colour-blind-safe palette (true bg colours, dark/light + cterm). The group
--- NAMES (NvimHighlightHero0..9, NvimHighlightHeroAuto) are stable API.

local M = {}

M.group_prefix = "NvimHighlightHero"
M.auto_group = "NvimHighlightHeroAuto"

-- Temporary links, overridden in Phase 3.
M.default_links = {
  [0] = "IncSearch",
  [1] = "DiffText",
  [2] = "Search",
  [3] = "DiffAdd",
  [4] = "DiffChange",
  [5] = "Visual",
  [6] = "WildMenu",
  [7] = "DiffDelete",
  [8] = "MatchParen",
  [9] = "Substitute",
}

--- Name of the highlight group backing a numbered group.
---@param group integer
---@return string
function M.name(group)
  return M.group_prefix .. group
end

--- Define the highlight groups (as defaults, so a user/colorscheme can override).
function M.apply()
  for group, link in pairs(M.default_links) do
    vim.api.nvim_set_hl(0, M.name(group), { link = link, default = true })
  end
  vim.api.nvim_set_hl(0, M.auto_group, { link = "Search", default = true })
end

return M
