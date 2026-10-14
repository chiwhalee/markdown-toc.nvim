local M = {}

--- Default configuration. See README.md for a full description of each option.
M.defaults = {
  -- Filetypes this plugin attaches to.
  filetypes = { "markdown", "tex" },

  -- Normal-mode keymap (in attached buffers) that opens the TOC.
  -- Set to `false` to disable the automatic keymap entirely (you can then
  -- call `require("mtoc").open()` yourself, e.g. from your own keymap).
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
}

M.options = vim.deepcopy(M.defaults)

--- Merge user options over the defaults and store the result.
---@param opts table|nil
---@return table
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
  return M.options
end

return M
