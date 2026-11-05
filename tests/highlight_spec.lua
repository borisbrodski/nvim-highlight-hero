local hl = require("nvim-highlight-hero.highlight")

local function set_buf(lines)
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

local function has_match(pattern)
  for _, m in ipairs(vim.fn.getmatches()) do
    if m.pattern == pattern then
      return true
    end
  end
  return false
end

describe("highlight bookkeeping", function()
  before_each(function()
    set_buf({ "foo foo bar" })
    vim.fn.clearmatches()
    hl.clear_all()
  end)

  it("set creates a tracked match", function()
    hl.set(1, "Search", [[\Vfoo]])
    assert.is_true(hl.is_set(1))
    assert.is_true(has_match([[\Vfoo]]))
  end)

  it("clear removes the group's matches", function()
    hl.set(1, "Search", [[\Vfoo]])
    hl.clear(1)
    assert.is_false(hl.is_set(1))
    assert.is_false(has_match([[\Vfoo]]))
  end)

  it("toggle turns the same pattern off and a new one on", function()
    assert.equals("on", hl.toggle(2, "Search", [[\Vfoo]]))
    assert.equals("off", hl.toggle(2, "Search", [[\Vfoo]]))
    assert.equals("on", hl.toggle(2, "Search", [[\Vbar]]))
    assert.is_true(hl.is_set(2))
  end)

  it("add appends and defeats toggling", function()
    hl.set(3, "Search", [[\Vfoo]])
    hl.add(3, "Search", [[\Vbar]])
    assert.is_true(has_match([[\Vfoo]]))
    assert.is_true(has_match([[\Vbar]]))
    -- after append, re-setting the old pattern does not toggle off
    assert.equals("on", hl.toggle(3, "Search", [[\Vfoo]]))
  end)

  it("clear_all removes every group", function()
    hl.set(1, "Search", [[\Vfoo]])
    hl.set(2, "Search", [[\Vbar]])
    hl.clear_all()
    assert.is_false(hl.is_set(1))
    assert.is_false(hl.is_set(2))
    assert.are.same({}, hl.active_groups())
  end)

  it("active_groups lists set groups in order", function()
    hl.set(3, "Search", [[\Vbar]])
    hl.set(1, "Search", [[\Vfoo]])
    assert.are.same({ 1, 3 }, hl.active_groups())
  end)
end)
