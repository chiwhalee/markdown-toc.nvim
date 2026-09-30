-- Basic, dependency-free test suite for markdown-toc.nvim.
--
-- Run with:
--   nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/test_toc.lua')"
--
-- Exits with code 0 on success, 1 on the first failure (via os.exit through
-- vim.cmd("cquit"), since headless Neovim doesn't return non-zero otherwise).

local toc = require("markdown-toc.toc")

local failures = 0

local function check(name, cond)
  if cond then
    print("  ok - " .. name)
  else
    failures = failures + 1
    print("  FAIL - " .. name)
  end
end

local function describe(name, fn)
  print(name)
  fn()
end

describe("markdown heading parser", function()
  local parse = toc.heading_parsers.markdown

  local level, title = parse("# Hello World")
  check("parses level-1 heading", level == 1)
  check("parses title text", title == "Hello World")

  level, title = parse("### Nested Heading  ")
  check("parses level-3 heading", level == 3)
  check("trims trailing whitespace", title == "Nested Heading")

  level = parse("not a heading")
  check("rejects non-heading lines", level == nil)

  level = parse("#NoSpaceAfterHash")
  check("rejects '#' without following space", level == nil)
end)

describe("LaTeX heading parser", function()
  local parse = toc.heading_parsers.tex

  local level, title = parse("\\section{Introduction}")
  check("parses \\section as level 2", level == 2)
  check("parses \\section title", title == "Introduction")

  level, title = parse("\\subsection*{Motivation}")
  check("parses starred \\subsection* as level 3", level == 3)
  check("parses \\subsection* title", title == "Motivation")

  level, title = parse("\\chapter{Overview}")
  check("parses \\chapter as level 1", level == 1)

  level = parse("This is body text.")
  check("rejects non-heading lines", level == nil)

  level = parse("\\textbf{not a heading command}")
  check("rejects unrelated LaTeX commands", level == nil)
end)

print("")
if failures > 0 then
  print(failures .. " failure(s).")
  vim.cmd("cquit")
else
  print("All tests passed.")
  vim.cmd("qa!")
end
