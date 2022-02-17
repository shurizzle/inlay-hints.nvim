local utils = require('inlay-hints.utils')

local function fix_range(range)
  local new_range = vim.tbl_deep_extend('force', {}, range)
  new_range.start.line = new_range.start.line + 1
  new_range.start.character = new_range.start.character + 1
  new_range['end'].line = new_range['end'].line + 1
  new_range['end'].character = new_range['end'].character + 1
  return new_range
end

-- [1]: error
-- [2]: v
--   kind: TypeHint, label: type, range
--   kind: ParameterHint, label: name, range
--   kind: ChainingHint, label: type, range
-- [3]: {bufnr, client_id, method, params={textDocument={uri}}}
-- [4]: config
local function handler(error, hints, info, _, callback)
  if error then
    callback(error)
    return
  end

  if vim.api.nvim_get_current_buf() ~= info.bufnr then
    return
  end

  local save_hints = { variables = {}, returns = {} }

  for _, hint in ipairs(hints) do
    if hint.kind == 'TypeHint' then
      local range = fix_range(hint.range)
      local _hint = {
        type = hint.label,
        name = utils.get_text(info.bufnr, range),
        range = range,
      }

      table.insert(save_hints.variables, _hint)
    elseif hint.kind == 'ChainingHint' then
      local _hint = {
        type = hint.label,
        range = fix_range(hint.range),
      }
      table.insert(save_hints.returns, _hint)
    end
  end

  vim.fn.setbufvar(
    info.bufnr,
    'inlay_hints_last_response',
    vim.tbl_deep_extend('force', {}, save_hints)
  )

  callback(nil, save_hints)
end

local function callback_handler(callback)
  return function(a, b, c, d)
    handler(a, b, c, d, callback)
  end
end

local function get_hints(bufnr, callback)
  utils.request(
    bufnr or 0,
    'rust-analyzer/inlayHints',
    utils.get_params(bufnr),
    callback_handler(callback)
  )
end

local function on_server_start(_, result)
  local bufnr = vim.api.nvim_get_current_buf()

  if utils.buf_has_lsp(bufnr, 'rust_analyzer') then
    require('inlay-hints').set_inlay_hints(bufnr, 'rust_analyzer')
  end
end

local function lsp_handlers()
  -- compatibility with rust-tools
  local ok, rust_tools = pcall(require, 'rust-tools.server_status')
  local server_status = on_server_start
  if ok then
    server_status = utils.concat_functions(rust_tools.handler, server_status)
  end

  return {
    ['experimental/serverStatus'] = utils.make_handler(server_status),
  }
end

return require('inlay-hints.lsp').Server:new({
  lsp_handlers = lsp_handlers,
  get_hints = get_hints,
})
