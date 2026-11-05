local sel = require("nvim-highlight-hero.selection")

local function set_buf(lines)
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

describe("word_under_cursor", function()
  it("returns the keyword under the cursor", function()
    set_buf({ "alpha beta gamma" })
    vim.fn.cursor(1, 8) -- on 'beta'
    assert.equals("beta", sel.word_under_cursor())
  end)

  it("returns empty on blank space", function()
    set_buf({ "   " })
    vim.fn.cursor(1, 2)
    assert.equals("", sel.word_under_cursor())
  end)
end)

describe("visual characterwise", function()
  it("captures a characterwise selection", function()
    set_buf({ "hello world" })
    feed("gg0v4l<Esc>") -- select 'hello'
    local r = sel.visual()
    assert.is_not_nil(r)
    assert.equals("hello", r.text)
    assert.is_false(r.linewise)
    assert.is_false(r.blockwise)
  end)

  it("is multibyte-safe", function()
    set_buf({ "äöü rest" })
    feed("gg0v2l<Esc>") -- select the three umlaut chars
    local r = sel.visual()
    assert.is_not_nil(r)
    assert.equals("äöü", r.text)
  end)
end)

describe("visual linewise", function()
  it("captures full lines and flags linewise", function()
    set_buf({ "  foo", "    bar" })
    feed("ggVj<Esc>")
    local r = sel.visual()
    assert.is_not_nil(r)
    assert.is_true(r.linewise)
    assert.are.same({ "  foo", "    bar" }, r.lines)
  end)
end)

describe("visual blockwise", function()
  it("captures a column block", function()
    set_buf({ "abcd", "efgh", "ijkl" })
    feed("gg0<C-v>2jl<Esc>") -- 2-wide block down 3 rows
    local r = sel.visual()
    assert.is_not_nil(r)
    assert.is_true(r.blockwise)
    assert.are.same({ "ab", "ef", "ij" }, r.lines)
  end)
end)
