local colors = require("nvim-highlight-hero.colors")

local function hex_dist(a, b)
  local function rgb(h)
    h = h:gsub("#", "")
    return tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
  end
  local ar, ag, ab = rgb(a)
  local br, bg, bb = rgb(b)
  return math.sqrt((ar - br) ^ 2 + (ag - bg) ^ 2 + (ab - bb) ^ 2)
end

-- Minimum pairwise distance between the ten group backgrounds, optionally
-- after a colour-vision transform.
local function min_pairwise(transform)
  local m = math.huge
  for i = 0, 9 do
    for j = i + 1, 9 do
      local a, b = colors.current[i].bg, colors.current[j].bg
      if transform then
        a, b = transform(a), transform(b)
      end
      m = math.min(m, hex_dist(a, b))
    end
  end
  return m
end

describe("colour palette", function()
  after_each(function()
    vim.o.background = "dark"
  end)

  it("defines all ten groups and the auto group", function()
    vim.o.background = "dark"
    colors.apply()
    for g = 0, 9 do
      local hl = vim.api.nvim_get_hl(0, { name = colors.name(g) })
      assert.is_not_nil(hl.bg, colors.name(g) .. " should have a bg")
      assert.is_not_nil(hl.fg, colors.name(g) .. " should have a fg")
      assert.is_not_nil(hl.ctermbg, colors.name(g) .. " should have a ctermbg")
    end
    assert.is_not_nil(vim.api.nvim_get_hl(0, { name = colors.auto_group }).bg)
  end)

  it("gives every group a readable foreground (contrast >= 4.5) on both backgrounds", function()
    for _, mode in ipairs({ "dark", "light" }) do
      vim.o.background = mode
      colors.apply()
      for g = 0, 9 do
        local e = colors.current[g]
        assert.is_true(
          colors.contrast_ratio(e.bg, e.fg) >= 4.5,
          ("group %d (%s) contrast too low in %s mode"):format(g, e.bg, mode)
        )
      end
    end
  end)

  it("uses ten clearly distinct backgrounds", function()
    vim.o.background = "dark"
    colors.apply()
    assert.is_true(min_pairwise(nil) >= 25, "normal-vision min pairwise distance")
  end)

  it("stays distinguishable under deuteranopia and protanopia", function()
    vim.o.background = "dark"
    colors.apply()
    assert.is_true(min_pairwise(colors.simulate_deuteranopia) >= 10, "deuteranopia separation")
    assert.is_true(min_pairwise(colors.simulate_protanopia) >= 25, "protanopia separation")
  end)

  it("computes in-range 256-colour fallbacks", function()
    vim.o.background = "dark"
    colors.apply()
    for g = 0, 9 do
      local c = colors.current[g].ctermbg
      assert.is_true(c >= 16 and c <= 255, "cterm index should be a real palette index")
    end
  end)

  it("honours a user background override", function()
    vim.o.background = "dark"
    colors.apply({ [0] = "#123456" })
    assert.equals("#123456", colors.current[0].bg)
  end)

  it("deepens the hues for a light background", function()
    vim.o.background = "dark"
    colors.apply()
    local dark0 = colors.current[0].bg
    vim.o.background = "light"
    colors.apply()
    local light0 = colors.current[0].bg
    assert.are_not.equal(dark0, light0)
    assert.is_true(colors.luminance(light0) < colors.luminance(dark0), "light variant should be darker")
  end)

  it("preview renders without error", function()
    vim.o.background = "dark"
    colors.apply()
    assert.has_no.errors(function()
      colors.preview()
    end)
  end)
end)
