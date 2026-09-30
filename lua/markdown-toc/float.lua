-- Self-contained centered floating window helper, used only by markdown-toc.
-- This deliberately has no external dependencies, so the plugin doesn't rely
-- on any third-party or personal floating-window library.
local M = {}

--- Open a centered, scratch floating window showing `opts.content`.
---@param opts table {
---   title: string|nil,
---   filetype: string|nil,
---   content: string[],
---   width: number  (fraction of editor columns, e.g. 0.8),
---   height: number (fraction of editor lines, e.g. 0.7),
---   on_submit: fun(buf:number, win:number)|nil  -- called on <CR>
---   keymaps: table<string, fun(buf:number, win:number, close:fun())>|nil
---     -- override/extend the default q/<Esc>/<CR> keymaps
--- }
---@return table|nil { buf = number, win = number, close = fun() }
function M.open(opts)
  opts = opts or {}
  local content = opts.content or {}

  local width = math.max(1, math.floor(vim.o.columns * (opts.width or 0.8)))
  local height = math.max(1, math.floor(vim.o.lines * (opts.height or 0.7)))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  if opts.filetype then
    vim.bo[buf].filetype = opts.filetype
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false

  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  }
  if opts.title then
    win_opts.title = opts.title
    win_opts.title_pos = "center"
  end

  local win = vim.api.nvim_open_win(buf, true, win_opts)

  local closed = false
  local function close()
    if closed then
      return
    end
    closed = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  local default_keymaps = {
    q = function(_, _, c)
      c()
    end,
    ["<Esc>"] = function(_, _, c)
      c()
    end,
    ["<CR>"] = function(b, w, c)
      if opts.on_submit then
        opts.on_submit(b, w)
      end
      c()
    end,
  }

  local keymaps = vim.tbl_extend("force", default_keymaps, opts.keymaps or {})
  for key, fn in pairs(keymaps) do
    vim.keymap.set("n", key, function()
      fn(buf, win, close)
    end, { buffer = buf, nowait = true, silent = true })
  end

  return { buf = buf, win = win, close = close }
end

return M
