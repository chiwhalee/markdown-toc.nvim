-- mtoc.nvim: a lightweight, native-fold-based Table of Contents
-- navigator for markdown (and LaTeX) buffers.
--
-- Usage:
--   require("mtoc").setup({ ... })  -- optional, see README for options
--
-- See doc/mtoc.txt or README.md for full documentation.
local config = require("mtoc.config")
local toc = require("mtoc.toc")

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
