# markdown-toc.nvim

A lightweight, native-fold-based Table of Contents navigator for **markdown**
(with bonus **LaTeX** support) in Neovim.

![markdown-toc.nvim in action](https://example.com/markdown-toc.png)

## Why this plugin?

Most outline/TOC plugins for Neovim (e.g. `aerial.nvim`, `symbols-outline.nvim`)
reimplement their own tree-rendering engine to display and collapse a
document's structure. `markdown-toc.nvim` takes a different approach: it
builds directly on **Neovim's native folding** (`foldexpr`/`foldtext`), which
keeps it small and dependency-free, while fixing the rough edges that make
raw Vim folding awkward for outline navigation:

- **Word/Acrobat-style collapsing** -- folding a heading collapses it down to
  exactly one line (`▸ Heading`), not Vim's default
  `+--  12 lines: Heading ---` summary.
- **Correct sibling nesting** -- two headings at the same level never
  accidentally merge into a single fold (a real limitation of naive
  `foldexpr` heading scripts).
- **Leaf headings aren't independently foldable** -- folding a heading with
  no sub-headings folds its nearest foldable ancestor instead, matching how
  outline views in Word/Acrobat/most tree UIs behave.
- **Consistent per-level colors**, preserved even while a section is folded
  (no gray "Folded" tint swallowing your heading colors).
- **Session-persistent fold state** -- collapse a few sections, close the
  TOC, reopen it later (even after editing the document) -- your fold state
  is remembered for as long as Neovim stays open.
- **Cursor sync** -- opening the TOC places the cursor on the heading
  corresponding to your current position in the document, without forcibly
  unfolding anything.

**Scope**: this plugin is designed and tested primarily for **Markdown**.
**LaTeX** sectioning commands (`\part`, `\chapter`, `\section`,
`\subsection`, `\subsubsection`, `\paragraph`, `\subparagraph`) are also
supported, but with a lighter level of polish/testing than Markdown.

## Requirements

- Neovim >= 0.9 (uses `nvim_buf_set_extmark` inline virtual text and
  `line_hl_group`).
- No other dependencies.

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/markdown-toc.nvim",
  ft = { "markdown", "tex" },
  opts = {},
}
```

Using `opts = {}` (rather than a `config` function) lets lazy.nvim call
`require("markdown-toc").setup(opts)` for you automatically.

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use({
  "yourusername/markdown-toc.nvim",
  ft = { "markdown", "tex" },
  config = function()
    require("markdown-toc").setup()
  end,
})
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'yourusername/markdown-toc.nvim'
```

```lua
require("markdown-toc").setup()
```

## Usage

Press `<leader>tc` (configurable) in a markdown or LaTeX buffer to open the
Table of Contents in a floating window.

Inside the TOC:

| Key         | Action                                                          |
|-------------|------------------------------------------------------------------|
| `<CR>`      | Jump to the heading under the cursor, and close the TOC           |
| `q` / `<Esc>` | Close the TOC                                                   |
| `zc` / `za` | Fold/toggle the heading under the cursor (or its nearest foldable ancestor, if it has no children) |
| `zC` / `zA` | Same, recursively                                                 |
| `zR` / `zM` | Open/close all folds (native Vim commands)                       |

## Configuration

Call `setup()` (even with no arguments) to enable the plugin's default
keymap and highlight groups:

```lua
require("markdown-toc").setup({
  -- Filetypes this plugin attaches to.
  filetypes = { "markdown", "tex" },

  -- Normal-mode keymap (in attached buffers) that opens the TOC.
  -- Set to `false` to disable the automatic keymap entirely (you can then
  -- call `require("markdown-toc").open()` yourself, e.g. from your own keymap).
  keymap = "<leader>tc",

  -- Floating window size, as a fraction of the editor's total columns/lines.
  width = 0.8,
  height = 0.7,

  -- Per-heading-level color/style. Only the levels listed here get a
  -- distinct color; any deeper level falls back to `fallback_hl`.
  -- Add more entries (e.g. `[4] = { fg = "...", bold = false }`) to give
  -- additional levels their own individual color.
  levels = {
    [1] = { fg = "#2563eb", bold = true },
    [2] = { fg = "#16a34a", bold = false },
    [3] = { fg = "#d97706", bold = false },
  },
  fallback_hl = { fg = "#2563eb", bold = false },

  -- Expand/collapse arrow indicator shown before headings that have children.
  arrow = {
    -- Set to `false` to fall back to Vim's default foldtext
    -- ("+--  N lines: ... ---") instead of the arrow + clean-text style.
    enabled = true,
    open_char = "▾", -- shown when the heading's fold is open (expanded)
    closed_char = "▸", -- shown when the heading's fold is closed (collapsed)
    hl = { fg = "#94a3b8", bold = false },
  },
})
```

### Alternative arrow glyphs

Some other glyph pairs you can swap in for `open_char` / `closed_char`:

| Style                | open_char | closed_char |
|----------------------|-----------|-------------|
| Small solid (default)| `▾`       | `▸`         |
| Larger/bolder solid  | `▼`       | `▶`         |
| Larger hollow         | `▽`       | `▷`         |
| Small hollow          | `▿`       | `▹`         |
| Plain ASCII           | `v`       | `>`         |
| Arrow-style           | `⤓`       | `➤`         |

## Known limitations

- Neovim/terminal UI has no concept of per-glyph font "size" -- only glyph
  choice, color, and attributes (bold/italic/etc). Pick a visually
  larger/smaller glyph instead if you want a different visual weight.
- Fold state is kept only in memory for the current Neovim session; it is
  not written to disk and will not persist across restarts.
- The LaTeX title parser uses a simple "first closing brace" match, so a
  title containing its own nested braces (e.g.
  `\section{Intro \textbf{Bold}}`) will be truncated at the first `}`.

## Running tests

```sh
nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/test_toc.lua')"
```

## License

MIT
