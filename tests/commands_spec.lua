require("nvim-highlight-hero").setup({})

local highlight = require("nvim-highlight-hero.highlight")

local function set_buf(lines)
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.fn.clearmatches()
  highlight.clear_all()
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

local function match_patterns()
  local out = {}
  for _, m in ipairs(vim.fn.getmatches()) do
    out[#out + 1] = m.pattern
  end
  return out
end

local function any_match(pred)
  for _, p in ipairs(match_patterns()) do
    if pred(p) then
      return true
    end
  end
  return false
end

describe(":HH", function()
  it("does not error and highlights the word under the cursor (regression)", function()
    set_buf({ "foo foo bar" })
    vim.fn.cursor(1, 1)
    assert.has_no.errors(function()
      vim.cmd("HH")
    end)
    assert.is_true(highlight.is_set(0))
    assert.is_true(any_match(function(p)
      return p == [[\V\c\<foo\>]]
    end))
  end)

  it("! uses a weak (substring, no boundary) match", function()
    set_buf({ "foobar foo" })
    vim.fn.cursor(1, 1)
    vim.cmd("HH!")
    assert.is_true(any_match(function(p)
      return p == [[\V\cfoobar]]
    end))
  end)

  it("accepts an explicit group number and literal text", function()
    set_buf({ "nothing here" })
    vim.cmd("HH 3 needle")
    assert.is_true(highlight.is_set(3))
    assert.is_true(any_match(function(p)
      return p == [[\V\c\<needle\>]]
    end))
  end)

  it("toggles the same pattern off on a repeat", function()
    set_buf({ "foo foo" })
    vim.fn.cursor(1, 1)
    vim.cmd("HH")
    assert.is_true(highlight.is_set(0))
    vim.fn.cursor(1, 1)
    vim.cmd("HH")
    assert.is_false(highlight.is_set(0))
  end)

  it("highlights a linewise selection with a merge pattern", function()
    set_buf({ "  if (x) {", "    if (x) {" })
    feed("ggVG<Esc>") -- linewise select both lines, set '< '> marks
    vim.cmd("'<,'>HH")
    assert.is_true(highlight.is_set(0))
    assert.is_true(any_match(function(p)
      return p:find([[\_^]], 1, true) ~= nil
    end))
  end)
end)

describe(":HHoff", function()
  it("clears a specific group", function()
    set_buf({ "foo" })
    vim.cmd("HH 2 foo")
    assert.is_true(highlight.is_set(2))
    vim.cmd("HHoff 2")
    assert.is_false(highlight.is_set(2))
  end)

  it("! clears all groups", function()
    set_buf({ "foo bar" })
    vim.cmd("HH 1 foo")
    vim.cmd("HH 2 bar")
    vim.cmd("HHoff!")
    assert.are.same({}, highlight.active_groups())
  end)

  it("with no argument clears the last set group", function()
    set_buf({ "foo bar" })
    vim.cmd("HH 1 foo")
    vim.cmd("HH 4 bar")
    vim.cmd("HHoff")
    assert.is_false(highlight.is_set(4))
    assert.is_true(highlight.is_set(1))
  end)
end)

describe("default keymaps", function()
  local function has_desc(mode, pat)
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      if m.desc and m.desc:match(pat) then
        return true
      end
    end
    return false
  end

  it("registers digit maps for normal and visual mode", function()
    assert.is_true(has_desc("n", "Highlight word %(group 0%)"))
    assert.is_true(has_desc("n", "Highlight word %(group 9%)"))
    assert.is_true(has_desc("x", "Highlight selection %(group 1%)"))
  end)

  it("registers the off maps", function()
    assert.is_true(has_desc("n", "Clear last highlight group"))
    assert.is_true(has_desc("n", "Clear all highlight groups"))
  end)
end)
