-- Minimal init used only for running the test suite headlessly. Adds this
-- plugin's `lua/` directory to the runtimepath so `require("markdown-toc...")`
-- works without needing it to be installed via a plugin manager.
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.rtp:prepend(plugin_root)
