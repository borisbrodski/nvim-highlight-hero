local auto = require("nvim-highlight-hero.auto")

local function set_buf(lines)
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.fn.clearmatches()
  auto.disable()
end

local function auto_pattern()
  for _, m in ipairs(vim.fn.getmatches()) do
    if m.group == "NvimHighlightHeroAuto" then
      return m.pattern
    end
  end
  return nil
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

describe("auto-highlight", function()
  before_each(function()
    set_buf({ "foo foo bar", "baz foo" })
  end)

  it("is off by default; toggle enables and highlights the word under cursor", function()
    assert.is_false(auto.enabled)
    vim.fn.cursor(1, 1)
    assert.is_true(auto.toggle("strong"))
    auto.update()
    assert.equals([[\V\c\<foo\>]], auto_pattern())
  end)

  it("updates as the cursor moves to a new word", function()
    auto.enable("strong")
    vim.fn.cursor(1, 1)
    auto.update()
    assert.equals([[\V\c\<foo\>]], auto_pattern())
    vim.fn.cursor(1, 9) -- on 'bar'
    auto.update()
    assert.equals([[\V\c\<bar\>]], auto_pattern())
  end)

  it("toggles off and removes the match", function()
    auto.enable("strong")
    vim.fn.cursor(1, 1)
    auto.update()
    assert.is_not_nil(auto_pattern())
    assert.is_false(auto.toggle("strong"))
    assert.is_nil(auto_pattern())
  end)

  it("weak preset matches a substring without boundaries", function()
    set_buf({ "foobar foo" })
    auto.enable("weak")
    vim.fn.cursor(1, 1)
    auto.update()
    assert.equals([[\V\cfoobar]], auto_pattern())
  end)

  it("switches preset without turning off", function()
    vim.fn.cursor(1, 1)
    assert.is_true(auto.toggle("strong"))
    assert.is_true(auto.toggle("weak"))
    assert.is_true(auto.enabled)
    assert.equals("weak", auto.preset)
  end)

  it("clears when the cursor sits on non-word whitespace", function()
    set_buf({ "foo   " })
    auto.enable("strong")
    vim.fn.cursor(1, 5)
    auto.update()
    assert.is_nil(auto_pattern())
  end)

  it("does not highlight the next word when the cursor is on indentation", function()
    set_buf({ "    os.contains", "    os.foo" })
    auto.enable("strong")
    vim.fn.cursor(1, 2) -- a leading space; the cursor is not on 'os'
    auto.update()
    assert.is_nil(auto_pattern())
  end)
end)

-- The headline merge workflow: with auto on, visually selecting lines lights
-- up every indentation-variant of them. The highlight is computed while the
-- selection is live, so we capture it from inside a visual-mode mapping.
describe("auto-highlight merge workflow", function()
  it("linewise selection yields a merge pattern that ignores indentation", function()
    set_buf({ "  if (x) {", "      if (x) {", "  other" })
    auto.enable("strong")

    local captured
    vim.keymap.set("x", "<F2>", function()
      auto.update()
      captured = auto_pattern()
    end)
    feed("ggV<F2><Esc>") -- linewise-select the one line, capture while visual
    pcall(vim.keymap.del, "x", "<F2>")

    assert.is_not_nil(captured, "a merge pattern should be produced while visually selecting")
    assert.is_not_nil(captured:find([[\_^]], 1, true), "should be a merge (line-anchored) pattern")
    -- the single-line merge pattern matches every indentation-variant of the line
    local re = vim.regex(captured)
    assert.is_not_nil(re:match_str("  if (x) {"), "matches the 2-space indent")
    assert.is_not_nil(re:match_str("          if (x) {"), "matches a 10-space indent")
  end)
end)

describe("auto-highlight via :HHauto and the CursorMoved autocmd", function()
  require("nvim-highlight-hero").setup({})

  it("enables live and refreshes on CursorMoved", function()
    vim.cmd("enew!")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha beta", "beta alpha" })
    vim.fn.clearmatches()
    auto.disable()

    vim.fn.cursor(1, 1)
    vim.cmd("HHauto") -- enable; highlights 'alpha'
    assert.equals([[\V\c\<alpha\>]], auto_pattern())

    vim.fn.cursor(1, 7) -- on 'beta'
    vim.api.nvim_exec_autocmds("CursorMoved", {})
    assert.equals([[\V\c\<beta\>]], auto_pattern())

    vim.cmd("HHauto") -- disable (cleanup)
    assert.is_nil(auto_pattern())
  end)
end)
