-- Core Table-of-Contents logic: heading parsing (markdown + LaTeX), floating
-- window rendering, per-level highlighting, arrow indicators, native
-- Vim-fold-based collapsing (with correct nesting semantics), session-only
-- fold-state persistence, and cursor synchronization with the source buffer.
local M = {}

local config = require("mtoc.config")
local float = require("mtoc.float")

-- Per-filetype heading parser: given a single line of text, returns
-- (level, title_text) if that line is a heading, or nil otherwise.
-- To support another filetype, add another entry here.
M.heading_parsers = {
  markdown = function(line)
    local hashes, title_text = line:match("^(#+)%s+(.-)%s*$")
    if not hashes then
      return nil
    end
    title_text = title_text:gsub("%s+#+$", "") -- clean up trailing hashes
    return #hashes, title_text
  end,

  tex = (function()
    -- LaTeX sectioning commands, in hierarchical order. \part is treated as
    -- the same level as \chapter for simplicity, since it is rarely used.
    local LATEX_LEVELS = {
      part = 1,
      chapter = 1,
      section = 2,
      subsection = 3,
      subsubsection = 4,
      paragraph = 5,
      subparagraph = 6,
    }
    return function(line)
      -- Matches \section{Title}, \section*{Title}, \subsection{Title}, etc.
      -- NOTE: uses a simple "first closing brace" match, so a title
      -- containing its own nested braces (e.g. \section{A \textbf{B}})
      -- will be truncated at the first "}". Good enough for typical titles.
      local cmd, title_text = line:match("^%s*\\(%a+)%*?%s*{(.-)}")
      local level = cmd and LATEX_LEVELS[cmd]
      if not level then
        return nil
      end
      return level, title_text
    end
  end)(),
}

-- Session-only state (lives only in memory; resets when Neovim quits).
local folded_titles = {} -- [src_bufnr] = { [title] = true, ... }
local fold_levels = {} -- [toc_bufnr] = { [lnum] = level, ... }
local indent_lens = {} -- [toc_bufnr] = { [lnum] = indent_len, ... }

-- Check whether line `lnum` is itself the START of a closed fold in `win`
-- (not merely a line nested inside some ancestor's closed fold).
local function is_fold_closed(win, lnum)
  local ok, result = pcall(vim.api.nvim_win_call, win, function()
    return vim.fn.foldclosed(lnum) == lnum
  end)
  return ok and result
end

-- Fold expression: every heading gets an explicit ">level" fold-start. This
-- is required for correct nesting in all cases (including a leaf heading
-- that immediately follows a deeper nested sibling's children), and to
-- avoid same-level sibling headings incorrectly merging into one fold
-- (which happens with plain numeric fold levels). Leaf headings do
-- technically get their own single-line fold too; to prevent them from
-- being independently closable, see the zc/za/zC/zA keymaps in `M.open()`,
-- which redirect the fold command to the nearest ancestor with children.
function _G.__markdown_toc_foldexpr()
  local buf = vim.api.nvim_get_current_buf()
  local levels = fold_levels[buf]
  local level = levels and levels[vim.v.lnum]
  if not level then
    return 0
  end
  return ">" .. level
end

-- foldtext: replaces the default "+-- N lines: ... ---" summary with just
-- the heading's own text, prefixed by the closed-state arrow glyph placed
-- after the heading's own indentation. Must return a plain string (Neovim's
-- 'foldtext' does not support returning a list of colored chunks). Color is
-- instead applied via the whole-line highlight extmark set in `M.open()`,
-- which takes priority over the generic 'Folded' group.
function _G.__markdown_toc_foldtext()
  local opts = config.options
  local buf = vim.api.nvim_get_current_buf()
  local lnum = vim.v.foldstart
  local line = vim.fn.getline(lnum)
  local lens = indent_lens[buf]
  local ilen = (lens and lens[lnum]) or 0
  local indent_part = line:sub(1, ilen)
  local rest = line:sub(ilen + 1)
  return indent_part .. opts.arrow.closed_char .. " " .. rest
end

--- (Re-)apply the highlight groups derived from the current config. Called
--- automatically by `require("mtoc").setup()`.
---@param opts table
function M.apply_highlights(opts)
  for level, style in pairs(opts.levels) do
    vim.api.nvim_set_hl(0, "MarkdownTocLevel" .. level, {
      fg = style.fg,
      bold = style.bold,
      bg = "NONE", -- keeps the level's color intact even on closed-fold lines
    })
  end
  vim.api.nvim_set_hl(0, "MarkdownTocFallback", {
    fg = opts.fallback_hl.fg,
    bold = opts.fallback_hl.bold,
    bg = "NONE",
  })
  vim.api.nvim_set_hl(0, "MarkdownTocArrow", {
    fg = opts.arrow.hl.fg,
    bold = opts.arrow.hl.bold,
  })
end

local function level_hl_group(opts, level)
  if opts.levels[level] then
    return "MarkdownTocLevel" .. level
  end
  return "MarkdownTocFallback"
end

--- Open the Table of Contents floating window for the current buffer.
function M.open()
  local opts = config.options
  local main_win = vim.api.nvim_get_current_win()
  local src_buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local parse_heading = M.heading_parsers[vim.bo[src_buf].filetype]
  if not parse_heading then
    vim.notify(
      "mtoc: unsupported filetype '" .. vim.bo[src_buf].filetype .. "'",
      vim.log.levels.WARN
    )
    return
  end

  local toc_items = {}
  local display_lines = {}

  for line_idx, line in ipairs(lines) do
    local level, title_text = parse_heading(line)
    if level then
      local indent = string.rep("  ", level - 1)
      table.insert(toc_items, {
        line_num = line_idx,
        level = level,
        title = title_text,
        indent_len = #indent,
      })
      table.insert(display_lines, indent .. title_text)
    end
  end

  if #toc_items == 0 then
    vim.notify("mtoc: no headings found", vim.log.levels.WARN)
    return
  end

  -- Statically determine which headings have children (i.e. are immediately
  -- followed by a heading of a deeper level) -- used both for the open-state
  -- arrow prefix (leaf headings get none) AND for the zc/za redirect below.
  for i, item in ipairs(toc_items) do
    local next_item = toc_items[i + 1]
    item.has_children = next_item ~= nil and next_item.level > item.level
  end

  -- Find the TOC entry corresponding to the source buffer's current cursor
  -- line (the last heading whose line_num <= current cursor line).
  local current_line = vim.api.nvim_win_get_cursor(main_win)[1]
  local cursor_toc_index = 1
  for i, item in ipairs(toc_items) do
    if item.line_num <= current_line then
      cursor_toc_index = i
    else
      break
    end
  end

  local res = float.open({
    title = " Table of Contents ",
    filetype = "text",
    content = display_lines,
    width = opts.width,
    height = opts.height,
    on_submit = function(_, win)
      local cursor_row = vim.api.nvim_win_get_cursor(win)[1]
      local target = toc_items[cursor_row]
      if target then
        vim.api.nvim_set_current_win(main_win)
        vim.api.nvim_win_set_cursor(main_win, { target.line_num, 0 })
        vim.cmd("normal! zt")
      end
    end,
    keymaps = {
      q = function(buf, win, close)
        local saved = {}
        for i, item in ipairs(toc_items) do
          if is_fold_closed(win, i) then
            saved[item.title] = true
          end
        end
        folded_titles[src_buf] = saved
        fold_levels[buf] = nil
        indent_lens[buf] = nil
        close()
      end,
      ["<Esc>"] = function(buf, win, close)
        local saved = {}
        for i, item in ipairs(toc_items) do
          if is_fold_closed(win, i) then
            saved[item.title] = true
          end
        end
        folded_titles[src_buf] = saved
        fold_levels[buf] = nil
        indent_lens[buf] = nil
        close()
      end,
    },
  })

  if not (res and res.buf) then
    return
  end

  local toc_buf, toc_win = res.buf, res.win

  -- Apply per-level highlight (whole-line, so it persists correctly even
  -- when the line displays closed-fold foldtext content).
  local ns_id = vim.api.nvim_create_namespace("markdown_toc_highlights")
  for i, item in ipairs(toc_items) do
    vim.api.nvim_buf_set_extmark(toc_buf, ns_id, i - 1, 0, {
      line_hl_group = level_hl_group(opts, item.level),
      priority = 200,
    })
  end

  -- Open-state arrow: inline virtual text placed right after the heading's
  -- indentation. Headings without children get a blank prefix of the same
  -- width instead, so text columns stay aligned across siblings.
  if opts.arrow.enabled then
    for i, item in ipairs(toc_items) do
      local prefix = item.has_children and (opts.arrow.open_char .. " ") or "  "
      vim.api.nvim_buf_set_extmark(toc_buf, ns_id, i - 1, item.indent_len, {
        virt_text = { { prefix, "MarkdownTocArrow" } },
        virt_text_pos = "inline",
        priority = 200,
      })
    end
  end

  vim.bo[toc_buf].filetype = "text"

  -- Build the {line -> level} / {line -> indent length} lookups consumed by
  -- __markdown_toc_foldexpr / __markdown_toc_foldtext.
  local levels, ilens = {}, {}
  for i, item in ipairs(toc_items) do
    levels[i] = item.level
    ilens[i] = item.indent_len
  end
  fold_levels[toc_buf] = levels
  indent_lens[toc_buf] = ilens

  vim.wo[toc_win].foldmethod = "expr"
  vim.wo[toc_win].foldexpr = "v:lua.__markdown_toc_foldexpr()"
  vim.wo[toc_win].foldenable = true
  vim.wo[toc_win].foldlevel = 99 -- start fully expanded unless restored below
  vim.wo[toc_win].foldminlines = 0 -- allow single-line (single-child) folds
  vim.wo[toc_win].number = false
  vim.wo[toc_win].relativenumber = false
  vim.wo[toc_win].foldcolumn = "0"

  if opts.arrow.enabled then
    vim.wo[toc_win].foldtext = "v:lua.__markdown_toc_foldtext()"
    vim.wo[toc_win].fillchars = "fold: " -- no trailing dash-fill after foldtext
  end

  -- Restore previously collapsed headings for this source buffer
  -- (session-only). Deferred via vim.schedule to avoid a race condition with
  -- Neovim's first foldexpr evaluation for the newly created buffer.
  local closed_titles = folded_titles[src_buf]
  if closed_titles then
    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(toc_win) then
        return
      end
      for i, item in ipairs(toc_items) do
        if closed_titles[item.title] then
          pcall(vim.api.nvim_win_call, toc_win, function()
            vim.cmd(i .. "foldclose")
          end)
        end
      end
    end)
  end

  -- Place the TOC cursor on the heading matching the source buffer's
  -- current position, without forcing any enclosing fold open.
  pcall(vim.api.nvim_win_set_cursor, toc_win, { cursor_toc_index, 0 })

  -- Every heading technically gets its own single-line fold (see
  -- __markdown_toc_foldexpr's comment), but leaf headings (no children)
  -- should never be independently closable. These keymaps intercept the
  -- common fold-toggle commands: if invoked on a leaf, the cursor first
  -- jumps to the nearest ancestor WITH children, then the native fold
  -- command runs there instead.
  local function nearest_foldable_line(cursor_line)
    local item = toc_items[cursor_line]
    if not item or item.has_children then
      return cursor_line
    end
    for i = cursor_line - 1, 1, -1 do
      if toc_items[i].level < item.level then
        return i
      end
    end
    return cursor_line
  end

  for _, key in ipairs({ "zc", "za", "zC", "zA" }) do
    vim.keymap.set("n", key, function()
      local cursor_line = vim.api.nvim_win_get_cursor(toc_win)[1]
      local target_line = nearest_foldable_line(cursor_line)
      if target_line ~= cursor_line then
        vim.api.nvim_win_set_cursor(toc_win, { target_line, 0 })
      end
      vim.cmd("normal! " .. key)
    end, { buffer = toc_buf, desc = "TOC: fold nearest foldable ancestor" })
  end
end

return M
