local M = {}

local utils = require('inlay-hints.utils')

local renders = {}

function M.add(name, fn)
  if type(name) ~= 'string' or type(fn) ~= 'function' then
    error('Trying to add an unvalid render')
  end

  renders[name] = fn
end

function M.apply(render, bufnr, hints, set_extmark)
  if type(hints) ~= 'table' then
    return
  end

  bufnr = utils.ensure_bufnr(bufnr)
  local opts = {}

  if type(render) == 'table' then
    opts = vim.tbl_deep_extend('keep', { nil }, render)
    render = render[1]
  end

  if type(type) == 'string' then
    render = renders[render]
  end

  if type(render) ~= 'function' then
    render = renders['default']
  end

  render(bufnr, opts, hints, set_extmark)
end

local nerdfonts_options = {
  type_symbol = '‣ ',
  return_symbol = ' ',
  info_symbol = '// ',
}

local no_nerdfonts_options = {
  type_symbol = '> ',
  return_symbol = '< ',
  info_symbol = '// ',
}

local default_options = vim.tbl_deep_extend('keep', {
  nerdfonts = true,
  variable_separator = ': ',
  type_separator = ', ',
  return_separator = ', ',
  info_separator = ' / ',
  type_return_separator = ' ',
  return_info_separator = ' ',
  highlight = 'Comment',
}, nerdfonts_options)

M.add('default', function(bufnr, options, hints, set_extmark)
  if options.nerdfonts == nil then
    options.nerdfonts = true
  end

  options = vim.tbl_deep_extend(
    'keep',
    options,
    options.nerdfonts and nerdfonts_options or no_nerdfonts_options
  )

  options = vim.tbl_deep_extend('keep', options, default_options)

  local lines = {}

  for _, varhint in ipairs(hints.variables or {}) do
    local line = varhint.range['end'].line
    lines[line] = lines[line] or { types = '', returns = '', infos = '' }
    if string.len(lines[line].types) > 0 then
      lines[line].types = lines[line].types .. options.type_separator
    end
    lines[line].types = lines[line].types
      .. varhint.name
      .. options.variable_separator
      .. varhint.type
  end

  for _, rethint in ipairs(hints.returns or {}) do
    local line = rethint.range['end'].line
    lines[line] = lines[line] or { types = '', returns = '', infos = '' }
    if string.len(lines[line].returns) > 0 then
      lines[line].returns = lines[line].returns .. options.return_separator
    end
    lines[line].returns = lines[line].returns .. rethint.type
  end

  for _, infohint in ipairs(hints.infos or {}) do
    local line = infohint.range['end'].line
    lines[line] = lines[line] or { types = '', returns = '', infos = '' }
    if string.len(lines[line].infos) > 0 then
      lines[line].infos = lines[line].infos .. options.info_separator
    end
    lines[line].infos = lines[line].infos .. infohint.type
  end

  for line, hint in pairs(lines) do
    local text = ''

    if type(hint.types) == 'string' and string.len(hint.types) > 0 then
      text = options.type_symbol .. hint.types
    end

    if type(hint.returns) == 'string' and string.len(hint.returns) > 0 then
      if string.len(text) > 0 then
        text = text .. options.type_return_separator
      end
      text = text .. options.return_symbol .. hint.returns
    end

    if type(hint.infos) == 'string' and string.len(hint.infos) > 0 then
      if string.len(text) > 0 then
        text = text .. options.type_info_separator
      end
      text = text .. options.info_symbol .. hint.infos
    end

    if string.len(text) > 0 then
      set_extmark(line, 1, {
        virt_text_pos = 'eol',
        virt_text = { { text, options.highlight } },
        hl_mode = 'combine',
      })
    end
  end
end)

return M
