local M = {}

local utils = require('inlay-hints.utils')

local default_options = {
  nerdfonts = true,
  filter = nil,
  render = {
    type_symbol = '‣ ',
    return_symbol = ' ',
    variable_separator = ': ',
    type_separator = ', ',
    return_separator = ', ',
    type_return_separator = ' ',
    highlight = 'Comment',
  },
}

local no_nerdfonts_options = {
  render = {
    type_symbol = '> ',
    return_symbol = '< ',
  },
}

local options = nil

local namespace = vim.api.nvim_create_namespace('inlay-hints')

local filters = {
  current_line = function(bufnr)
    local line = utils.buf_get_current_line(bufnr)

    return function(range)
      return range['end'].line == line
    end
  end,
  ['nup-ndown'] = function(bufnr, opts)
    opts.up = opts.up or 5
    opts.up = opts.up < 0 and 0 or opts.up
    opts.down = opts.down or 5
    opts.down = opts.down < 0 and 0 or opts.down

    local line = utils.buf_get_current_line(bufnr)
    local start = line - opts.up
    local stop = line + opts.down

    return function(range)
      return range['end'].line >= start and range['end'].line <= stop
    end
  end,
}

local function make_autocmd(events, bufnr, server_name, method)
  return string.format(
    'autocmd %s %s :lua require"inlay-hints".%s(%s,%s)',
    events,
    (bufnr and bufnr ~= 0) and ('<buffer=' .. tostring(bufnr) .. '>')
      or '<buffer>',
    method,
    bufnr or 0,
    vim.inspect(server_name)
  )
end

local function default_render(bufnr, hints, set_extmark)
  local lines = {}

  for _, varhint in ipairs(hints.variables) do
    local line = varhint.range['end'].line
    lines[line] = lines[line] or { types = '', returns = '' }
    if string.len(lines[line].types) > 0 then
      lines[line].types = lines[line].types .. options.render.type_separator
    end
    lines[line].types = lines[line].types
      .. varhint.name
      .. options.render.variable_separator
      .. varhint.type
  end

  for _, rethint in ipairs(hints.returns) do
    local line = rethint.range['end'].line
    lines[line] = lines[line] or { types = '', returns = '' }
    if string.len(lines[line].returns) > 0 then
      lines[line].returns = lines[line].returns
        .. options.render.return_separator
    end
    lines[line].returns = lines[line].returns .. rethint.type
  end

  for line, hint in pairs(lines) do
    local text = ''

    if type(hint.types) == 'string' and string.len(hint.types) > 0 then
      text = options.render.type_symbol .. hint.types
    end

    if type(hint.returns) == 'string' and string.len(hint.returns) > 0 then
      if string.len(text) > 0 then
        text = text .. options.render.type_return_separator
      end
      text = text .. options.render.return_symbol .. hint.returns
    end

    if string.len(text) > 0 then
      set_extmark(line, 1, {
        virt_text_pos = 'eol',
        virt_text = { { text, options.render.highlight } },
        hl_mode = 'combine',
      })
    end
  end
end

local function apply_filter(bufnr, hints, filter)
  if (bufnr or 0) == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local opts = {}

  if type(filter) == 'string' then
    filter = filters[filter]
  elseif type(filter) == 'table' then
    opts = vim.tbl_deep_extend('keep', { nil }, filter)
    filter = filters[filter[1]]
  end

  if type(filter) ~= 'function' then
    return hints
  end

  filter = filter(bufnr, opts)

  local new_hints = { variables = {}, returns = {} }

  for _, hint in ipairs(hints.variables) do
    if filter(hint.range) then
      table.insert(new_hints.variables, vim.tbl_deep_extend('force', {}, hint))
    end
  end

  for _, hint in ipairs(hints.returns) do
    if filter(hint.range) then
      table.insert(new_hints.returns, vim.tbl_deep_extend('force', {}, hint))
    end
  end

  return new_hints
end

function M.options()
  return vim.tbl_deep_extend('force', {}, options)
end

function M.setup(opts)
  opts = opts or {}
  if opts.nerdfonts == nil then
    opts.nerdfonts = true
  end

  if not opts.nerdfonts then
    opts = vim.tbl_deep_extend('keep', opts, no_nerdfonts_options)
  end

  options = vim.tbl_deep_extend('keep', opts, default_options)
end

function M.setup_autocmd(bufnr, server_name)
  if (bufnr or 0) == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local cmd = string.format(
    'augroup inlay_hints_b%s\nau!\n%s\n%s\naugroup END',
    bufnr,
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

  filter = filter or function()
    return true
  end

  local hints = vim.fn.getbufvar(bufnr, 'inlay_hints_last_response', nil)
  if type(hints) == 'table' then
    M.render(bufnr, apply_filter(bufnr, hints, filter))
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

  (type(options.render) == 'function' and options.render or default_render)(
    bufnr,
    hints,
    set_extmark
  )
end

function M.oneshot_line(bufnr)
  M.oneshot(bufnr, 'current_line')
end

function M.oneshot(bufnr, filter)
  require('inlay-hints.lsp').get_hints(nil, bufnr, function(err, hints)
    if not err then
      if type(filter) == 'function' then
        hints = apply_filter(hints, filter)
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
          M.render(bufnr, apply_filter(bufnr, hints, options.filter))
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
