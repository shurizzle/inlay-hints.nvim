local M = {}

local utils = require('inlay-hints.utils')
local filters = require('inlay-hints.filters')
local renders = require('inlay-hints.renders')

local options = nil

local namespace = vim.api.nvim_create_namespace('inlay-hints')

local function make_autocmd(events, bufnr, server_name, method)
  return string.format(
    'autocmd %s %s :lua require"inlay-hints".%s(%s,%s)',
    events,
    ((bufnr or 0) ~= 0) and ('<buffer=' .. tostring(bufnr) .. '>') or '<buffer>',
    method,
    bufnr or 0,
    vim.inspect(server_name)
  )
end

M.add_filter = filters.add
M.add_render = renders.add

function M.options()
  return vim.tbl_deep_extend('force', {}, options)
end

function M.config(opts)
  options = type(opts) == 'table' and opts or {}
end

function M.setup(opts)
  M.config(opts)

  vim.lsp.start_client = (function(old_start_client)
    return function(options)
      return old_start_client(M.lsp_options(options.name, options))
    end
  end)(vim.lsp.start_client)
end

function M.setup_autocmd(bufnr, server_name)
  if (bufnr or 0) == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local cmd = string.format(
    'augroup InlayHints\nau! * %s\n%s\n%s\naugroup END',
    ((bufnr or 0) ~= 0) and ('<buffer=' .. tostring(bufnr) .. '>') or '<buffer>',
    make_autocmd(
      'BufEnter,BufWinEnter,TabEnter,BufWritePost',
      bufnr,
      server_name,
      'set_inlay_hints'
    ),
    make_autocmd('CursorMoved,CursorMovedI', bufnr, server_name, 'move_cursor')
  )

  vim.api.nvim_exec(cmd, false)
end

function M.on_attach(server, bufnr)
  return require('inlay-hints.lsp').on_attach(server, bufnr)
end

function M.clear_inlay_hints(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr or 0, namespace, 0, -1)
end

function M.enable()
  if (bufnr or 0) == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  vim.g.inlay_hints_enabled = 1
  for _, bufnr in ipairs(
    vim.api.nvim_eval('filter(range(1, bufnr(\'$\')), \'buflisted(v:val)\')')
  ) do
    vim.fn.setbufvar(bufnr, 'inlay_hints_enabled', 1)
  end
  M.oneshot()
end

function M.disable()
  vim.g.inlay_hints_enabled = 0
  for _, bufnr in ipairs(
    vim.api.nvim_eval('filter(range(1, bufnr(\'$\')), \'buflisted(v:val)\')')
  ) do
    M.clear_inlay_hints(bufnr)
  end
end

function M.buf_disable(bufnr)
  if (bufnr or 0) == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  vim.fn.setbufvar(bufnr, 'inlay_hints_enabled', 0)
  M.clear_inlay_hints(bufnr)
end

function M.buf_enable(bufnr)
  if (bufnr or 0) == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  require('inlay-hints.lsp').set_inlay_hints(bufnr)
  vim.fn.setbufvar(bufnr, 'inlay_hints_enabled', 1)
end

M.lsp_options = require('inlay-hints.lsp').lsp_options

function M.redraw(bufnr, filter)
  if (bufnr or 0) == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  M.clear_inlay_hints(bufnr)

  local hints = vim.fn.getbufvar(bufnr, 'inlay_hints_last_response', nil)
  if type(hints) == 'table' then
    M.render(bufnr, filters.apply(filter, bufnr, hints))
  end
end

function M.render(bufnr, hints)
  M.clear_inlay_hints(bufnr)
  local function set_extmark(line, character, ...)
    return vim.api.nvim_buf_set_extmark(
      bufnr,
      namespace,
      line - 1,
      character - 1,
      ...
    )
  end

  renders.apply(options.render, bufnr, hints, set_extmark)
end

function M.oneshot_line(bufnr)
  M.oneshot(bufnr, 'line')
end

function M.oneshot(bufnr, filter)
  require('inlay-hints.lsp').get_hints(nil, bufnr, function(err, hints)
    if not err then
      if type(filter) == 'function' then
        hints = filters.apply(filter, bufnr, hints)
      end
      M.render(bufnr, hints)
    end
  end)
end

function M.set_inlay_hints(bufnr, server_name)
  if utils.is_enabled(bufnr) then
    require('inlay-hints.lsp').get_hints(
      server_name,
      bufnr,
      function(error, hints)
        if not error then
          M.render(bufnr, filters.apply(options.filter, bufnr, hints))
        end
      end
    )
  end
end

function M.move_cursor(bufnr, _)
  if utils.is_enabled(bufnr) then
    if options.filter then
      M.redraw(bufnr, options.filter)
    end
  end
end

return M
