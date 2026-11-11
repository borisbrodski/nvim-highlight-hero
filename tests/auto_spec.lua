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

  -- Regression: a characterwise (v) multi-line selection used the line-anchored
  -- merge pattern, which cannot match a span that starts or ends mid-line - so
  -- nothing was highlighted at all, not even the selection itself.
  it("characterwise multi-line selection ignores indentation and line breaks", function()
    set_buf({
      "        Zustaendigkeit zust,",
      "        Branche branche, String sachgebiet)",
      "    Zustaendigkeit zust,",
      "    Branche branche)",
      "  Zustaendigkeit zust, Branche branche)",
      "  Zustaendigkeit zust, String sachgebiet)",
    })
    auto.enable("strong")

    local captured
    vim.keymap.set("x", "<F2>", function()
      auto.update()
      captured = auto_pattern()
    end)
    feed("gg^vj^ee<F2><Esc>") -- from 'Zustaendigkeit' to the end of 'branche'
    pcall(vim.keymap.del, "x", "<F2>")

    assert.is_not_nil(captured)
    local found = {}
    vim.fn.cursor(1, 1)
    local flags = "cW"
    while true do
      local l = vim.fn.search(captured, flags)
      if l == 0 then
        break
      end
      found[#found + 1] = l
      flags = "W"
    end
    assert.same({ 1, 3, 5 }, found)
  end)
end)

describe("auto-highlight via :HHauto and the CursorMoved autocmd", function()
  local hh = require("nvim-highlight-hero")

  local function fresh(lines)
    vim.cmd("enew!")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.fn.clearmatches()
    auto.disable()
  end

  local function move(row, col)
    vim.fn.cursor(row, col)
    vim.api.nvim_exec_autocmds("CursorMoved", {})
  end

  after_each(function()
    auto.disable()
    hh.setup({})
  end)

  it("debounces by default", function()
    hh.setup({})
    assert.equals(50, require("nvim-highlight-hero.config").defaults.auto.debounce)
    assert.equals(50, auto.debounce)
  end)

  it("with debounce = 0 the highlight follows every cursor move at once", function()
    hh.setup({ auto = { debounce = 0 } })
    fresh({ "alpha beta", "beta alpha" })
    vim.fn.cursor(1, 1)
    vim.cmd("HHauto") -- enable; highlights 'alpha'
    assert.equals([[\V\c\<alpha\>]], auto_pattern())

    move(1, 7) -- on 'beta'
    assert.equals([[\V\c\<beta\>]], auto_pattern())

    vim.cmd("HHauto") -- disable
    assert.is_nil(auto_pattern())
  end)

  it("debounced: a burst of cursor moves costs one update, after the cursor rests", function()
    hh.setup({ auto = { debounce = 30 } })
    fresh({ "alpha beta gamma delta", "beta alpha" })
    vim.fn.cursor(1, 1)
    vim.cmd("HHauto") -- enabling applies immediately
    assert.equals([[\V\c\<alpha\>]], auto_pattern())

    local updates = 0
    local orig = auto.update
    auto.update = function(...)
      updates = updates + 1
      return orig(...)
    end

    move(1, 7) -- beta
    move(1, 12) -- gamma
    move(1, 18) -- delta
    assert.equals(0, updates, "nothing is recomputed while the cursor keeps moving")
    assert.equals([[\V\c\<alpha\>]], auto_pattern(), "the previous highlight stays meanwhile")

    vim.wait(300, function()
      return updates > 0
    end, 5)
    auto.update = orig
    assert.equals(1, updates, "the whole burst is one update")
    assert.equals([[\V\c\<delta\>]], auto_pattern())
  end)

  it("turning auto-highlight off cancels a pending update", function()
    hh.setup({ auto = { debounce = 30 } })
    fresh({ "alpha beta" })
    vim.fn.cursor(1, 1)
    vim.cmd("HHauto")
    move(1, 7)
    vim.cmd("HHauto") -- off while the update is still pending
    vim.wait(120)
    assert.is_nil(auto_pattern())
  end)
end)

describe("auto-highlight across windows", function()
  local function auto_pattern_in(win)
    for _, m in ipairs(vim.fn.getmatches(win)) do
      if m.group == "NvimHighlightHeroAuto" then
        return m.pattern
      end
    end
    return nil
  end

  local function float_win()
    local buf = vim.api.nvim_create_buf(false, true)
    return vim.api.nvim_open_win(
      buf,
      false,
      { relative = "editor", row = 1, col = 1, width = 10, height = 2 }
    )
  end

  before_each(function()
    vim.cmd("silent! tabonly!")
    vim.cmd("silent! only!")
    set_buf({ "foo bar", "bar foo" })
    auto.all_windows = true
  end)

  after_each(function()
    auto.disable()
    auto.all_windows = true
    vim.cmd("silent! tabonly!")
    vim.cmd("silent! only!")
  end)

  it("is on by default", function()
    assert.is_true(require("nvim-highlight-hero.config").defaults.auto.all_windows)
  end)

  it("mirrors the highlight into the other windows of the tabpage", function()
    local w1 = vim.api.nvim_get_current_win()
    vim.cmd("vsplit")
    local w2 = vim.api.nvim_get_current_win()
    vim.cmd("new") -- a third window showing a different buffer
    local w3 = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(w1)

    auto.enable("strong")
    vim.fn.cursor(1, 1)
    auto.update()
    for _, w in ipairs({ w1, w2, w3 }) do
      assert.equals([[\V\c\<foo\>]], auto_pattern_in(w))
    end

    vim.fn.cursor(1, 5) -- on 'bar': every window follows
    auto.update()
    for _, w in ipairs({ w1, w2, w3 }) do
      assert.equals([[\V\c\<bar\>]], auto_pattern_in(w))
    end
  end)

  it("clears every window when there is nothing to highlight or auto is turned off", function()
    local w1 = vim.api.nvim_get_current_win()
    vim.cmd("vsplit")
    local w2 = vim.api.nvim_get_current_win()
    auto.enable("strong")
    vim.fn.cursor(1, 1)
    auto.update()
    assert.is_not_nil(auto_pattern_in(w1))

    vim.fn.cursor(1, 4) -- the space between the words
    auto.update()
    assert.is_nil(auto_pattern_in(w1))
    assert.is_nil(auto_pattern_in(w2))

    vim.fn.cursor(1, 1)
    auto.update()
    assert.is_not_nil(auto_pattern_in(w1))
    auto.disable()
    assert.is_nil(auto_pattern_in(w1))
    assert.is_nil(auto_pattern_in(w2))
  end)

  it("with all_windows = false only the current window is highlighted", function()
    auto.all_windows = false
    local w1 = vim.api.nvim_get_current_win()
    vim.cmd("vsplit")
    local w2 = vim.api.nvim_get_current_win()
    auto.enable("strong")
    vim.fn.cursor(1, 1)
    auto.update()
    assert.is_nil(auto_pattern_in(w1))
    assert.equals([[\V\c\<foo\>]], auto_pattern_in(w2))

    vim.api.nvim_set_current_win(w1) -- the highlight moves with the focus
    vim.fn.cursor(2, 1)
    auto.update()
    assert.equals([[\V\c\<bar\>]], auto_pattern_in(w1))
    assert.is_nil(auto_pattern_in(w2))
  end)

  it("leaves floating windows alone", function()
    local float = float_win()
    auto.enable("strong")
    vim.fn.cursor(1, 1)
    auto.update()
    assert.is_not_nil(auto_pattern())
    assert.is_nil(auto_pattern_in(float))
    vim.api.nvim_win_close(float, true)
  end)

  it("does not touch windows of other tabpages and follows a tab switch", function()
    local w1 = vim.api.nvim_get_current_win()
    auto.enable("strong")
    vim.fn.cursor(1, 1)
    auto.update()
    vim.cmd("tab split")
    local w2 = vim.api.nvim_get_current_win()
    vim.fn.cursor(1, 5)
    auto.update()
    assert.equals([[\V\c\<bar\>]], auto_pattern_in(w2))
    assert.is_nil(auto_pattern_in(w1)) -- the hidden tab's stale highlight is dropped
  end)

  it("setup() applies the option and new splits pick the highlight up", function()
    local hh = require("nvim-highlight-hero")
    hh.setup({ auto = { all_windows = false } })
    assert.is_false(auto.all_windows)
    hh.setup({})
    assert.is_true(auto.all_windows)

    vim.fn.cursor(1, 1)
    vim.cmd("HHauto")
    local w1 = vim.api.nvim_get_current_win()
    vim.cmd("vsplit") -- WinNew/WinEnter autocmds sync the new window
    local w2 = vim.api.nvim_get_current_win()
    assert.equals([[\V\c\<foo\>]], auto_pattern_in(w1))
    assert.equals([[\V\c\<foo\>]], auto_pattern_in(w2))
    vim.cmd("HHauto")
  end)

  it("<leader>hw switches between all windows and the current window live", function()
    require("nvim-highlight-hero").setup({})
    local lhs = vim.g.mapleader and "<leader>hw" or "\\hw"
    assert.is_not.equals("", vim.fn.maparg(lhs, "n"), "the toggle keymap is installed")

    local w1 = vim.api.nvim_get_current_win()
    vim.cmd("vsplit")
    local w2 = vim.api.nvim_get_current_win()
    vim.fn.cursor(1, 1)
    auto.enable("strong")
    assert.is_not_nil(auto_pattern_in(w1))

    assert.is_false(auto.toggle_all_windows()) -- off: the other window is cleared at once
    assert.is_nil(auto_pattern_in(w1))
    assert.is_not_nil(auto_pattern_in(w2))

    assert.is_true(auto.toggle_all_windows()) -- back on: it lights up again
    assert.is_not_nil(auto_pattern_in(w1))
    assert.is_false(auto.toggle_all_windows(false))
    assert.is_false(auto.all_windows)
  end)
end)
