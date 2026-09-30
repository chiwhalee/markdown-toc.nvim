-- markdown-toc.nvim: a lightweight, native-fold-based Table of Contents
-- navigator for markdown (and LaTeX) buffers.
--
-- Usage:
--   require("markdown-toc").setup({ ... })  -- optional, see README for options
--
-- See doc/markdown-toc.txt or README.md for full documentation.
local config = require("markdown-toc.config")
local toc = require("markdown-toc.toc")

local M = {}

--- Configure the plugin. Safe to call with no arguments to use the defaults.
---@param opts table|nil
function M.setup(opts)
  local options = config.setup(opts)
  toc.apply_highlights(options)

  if options.keymap then
    vim.api.nvim_create_autocmd("FileType", {
      pattern = options.filetypes,
      callback = function(ev)
        vim.keymap.set("n", options.keymap, M.open, {
          buffer = ev.buf,
          desc = "Open Table of Contents",
        })
      end,
    })
  end
end

--- Open the Table of Contents for the current buffer.
function M.open()
  toc.open()
end

return M
