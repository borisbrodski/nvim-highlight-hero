local pattern = require("nvim-highlight-hero.pattern")

describe("escape_literal", function()
  it("doubles backslashes", function()
    assert.equals([[a\\b]], pattern.escape_literal([[a\b]]))
  end)

  it("leaves \\V-literal specials untouched", function()
    assert.equals("a.b*c(d)[e]", pattern.escape_literal("a.b*c(d)[e]"))
  end)
end)

describe("split_lines", function()
  it("keeps blank lines", function()
    assert.are.same({ "a", "", "b" }, pattern.split_lines("a\n\nb"))
  end)

  it("keeps a trailing empty field", function()
    assert.are.same({ "a", "" }, pattern.split_lines("a\n"))
  end)

  it("handles a single line", function()
    assert.are.same({ "foo" }, pattern.split_lines("foo"))
  end)
end)

describe("case_atom", function()
  it("honours explicit sensitive / insensitive", function()
    assert.equals([[\c]], pattern.case_atom("insensitive", "FOO"))
    assert.equals([[\C]], pattern.case_atom("sensitive", "foo"))
  end)

  it("is smart by default (uppercase => sensitive)", function()
    assert.equals([[\c]], pattern.case_atom("smart", "foo"))
    assert.equals([[\C]], pattern.case_atom("smart", "Foo"))
    assert.equals([[\c]], pattern.case_atom(nil, "foo"))
  end)
end)

describe("build - single line", function()
  it("whole word, smartcase (lowercase)", function()
    assert.equals([[\V\c\<foo\>]], pattern.build("foo", { boundaries = true, case = "smart" }))
  end)

  it("whole word, smartcase (uppercase => \\C)", function()
    assert.equals([[\V\C\<Foo\>]], pattern.build("Foo", { boundaries = true, case = "smart" }))
  end)

  it("substring, case-insensitive", function()
    assert.equals([[\V\cfoo]], pattern.build("foo", { boundaries = false, case = "insensitive" }))
  end)

  it("keeps specials literal and escapes backslashes", function()
    assert.equals([[\V\Ca.b]], pattern.build("a.b", { case = "sensitive" }))
    assert.equals([[\V\Ca\\b]], pattern.build([[a\b]], { case = "sensitive" }))
  end)
end)

describe("build - exact multiline", function()
  it("joins lines with the \\n atom", function()
    assert.equals([[\V\ca\nb]], pattern.build("a\nb", { whitespace = "exact", case = "insensitive" }))
  end)
end)

describe("build - merge (ignore indentation)", function()
  it("single line is anchored and indentation-tolerant", function()
    assert.equals(
      [[\V\C\_^\s\*if (x) {\s\*\_$]],
      pattern.build("  if (x) {", { whitespace = "merge", case = "sensitive" })
    )
  end)

  it("trims every line", function()
    assert.equals(
      [[\V\c\_^\s\*a\s\*\n\s\*b\s\*\_$]],
      pattern.build("  a\n    b", { whitespace = "merge", case = "insensitive" })
    )
  end)

  it("preserves a blank line in the middle", function()
    assert.equals(
      [[\V\c\_^\s\*a\s\*\n\s\*\s\*\n\s\*b\s\*\_$]],
      pattern.build("a\n\nb", { whitespace = "merge", case = "insensitive" })
    )
  end)
end)

describe("build - auto whitespace", function()
  it("single line, no newline => exact", function()
    assert.equals([[\V\cfoo]], pattern.build("foo", {}))
  end)

  it("trailing newline (linewise) => merge, newline stripped", function()
    assert.equals([[\V\c\_^\s\*if (x) {\s\*\_$]], pattern.build("  if (x) {\n", {}))
  end)

  it("multiline => merge", function()
    assert.equals([[\V\c\_^\s\*a\s\*\n\s\*b\s\*\_$]], pattern.build("a\nb", {}))
  end)
end)

describe("presets", function()
  it("strong = whole word + smartcase", function()
    assert.equals([[\V\c\<foo\>]], pattern.build_preset("foo", "strong"))
  end)

  it("weak = substring + insensitive", function()
    assert.equals([[\V\cfoo]], pattern.build_preset("foo", "weak"))
  end)

  it("accepts overrides", function()
    assert.equals([[\V\C\<foo\>]], pattern.build_preset("foo", "strong", { case = "sensitive" }))
  end)
end)

-- The merge-conflict workflow from the Vim docs: selecting the `if (...) {`
-- line (linewise) must highlight every indentation-variant of it and nothing
-- else. Verified by running the generated pattern through Vim's own regex.
describe("merge pattern matches the Vim-doc conflict fixture", function()
  local fixture = {
    [[function test() {]], -- 1
    [[<<<<<<< ours]], -- 2
    [[  if (condition1) {]], -- 3  <= should match
    [[    print("Testing")]], -- 4
    [[||||||| base]], -- 5
    [[    if (condition1) {]], -- 6  <= should match (deeper indent)
    [[      print("TestIng")]], -- 7
    [[=======]], -- 8
    [[  if (condition1) {]], -- 9  <= should match
    [[    print("TestIng ")]], -- 10
    [[>>>>>>> theirs]], -- 11
    [[  }]], -- 12
    [[}]], -- 13
  }

  it("matches lines 3/6/9 and not the print/other lines", function()
    local pat = pattern.build("  if (condition1) {\n", {}) -- linewise selection of line 3
    local re = vim.regex(pat)
    local function matches(i)
      return re:match_str(fixture[i]) ~= nil
    end
    assert.is_true(matches(3), "line 3 should match")
    assert.is_true(matches(6), "line 6 (deeper indent) should match")
    assert.is_true(matches(9), "line 9 should match")
    assert.is_false(matches(1), "function line should not match")
    assert.is_false(matches(4), "print line should not match")
    assert.is_false(matches(7), "print line should not match")
    assert.is_false(matches(10), "print line should not match")
  end)
end)
