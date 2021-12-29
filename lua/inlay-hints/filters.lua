local M = {}

local utils = require('inlay-hints.utils')

local filters = {}

function M.add(name, fn)
  if type(name) ~= 'string' or type(fn) ~= 'function' then
    error('Trying to add an unvalid filter')
  end

  filters[name] = fn
end

function M.apply(filter, bufnr, hints)
  bufnr = utils.ensure_bufnr(bufnr)
  local opts = {}

  if type(filter) == 'table' then
    opts = vim.tbl_deep_extend('keep', { nil }, filter)
    filter = filter[1]
  end

  if type(type) == 'string' then
    filter = filters[filter]
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

M.add('line', function(bufnr, opts)
  opts.offset = opts.offset or 0
  local line = utils.buf_get_current_line(bufnr) + opts.offset

  return function(range)
    return range['end'].line == line
  end
end)

M.add('nup-ndown', function(bufnr, opts)
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
end)

return M
