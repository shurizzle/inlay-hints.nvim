local utils = require('inlay-hints.utils')

-- [1]: error
-- [2]: v
--   kind: TypeHint, label: type, range
--   kind: ParameterHint, label: name, range
--   kind: ChainingHint, label: type, range
-- [3]: {bufnr, client_id, method, params={textDocument={uri}}}
-- [4]: config
local function handler(error, hints, info, _, filter)
  if error then
    return
  end

  if vim.api.nvim_get_current_buf() ~= info.bufnr then
    return
  end

  local new_hints = { variables = {}, returns = {} }

  for _, hint in ipairs(hints) do
    if hint.kind == 'TypeHint' then
      if filter(hint.range) then
        table.insert(new_hints.variables, {
          type = hint.label,
          name = utils.get_text(info.bufnr, hint.range),
          range = hint.range,
        })
      end
    elseif hint.kind == 'ChainingHint' then
      if filter(hint.range) then
        table.insert(new_hints.returns, {
          type = hint.label,
          range = hint.range,
        })
      end
    end
  end

  require('inlay-hints').render(info.bufnr, new_hints)
end

local function filtered_handler(filter)
  return function(...)
    handler(
      select(1, ...),
      select(2, ...),
      select(3, ...),
      select(4, ...),
      filter
    )
  end
end

local function set_inlay_hints(bufnr, filter)
  utils.request(
    bufnr,
    'rust-analyzer/inlayHints',
    utils.get_params(),
    filtered_handler(filter or function()
      return true
    end)
  )
end

local function on_server_start(_, result)
  local bufnr = vim.api.nvim_get_current_buf()

  if utils.buf_has_lsp(bufnr, 'rust_analyzer') then
    set_inlay_hints(
      bufnr --[[, TODO: filter function ]]
    )
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
  set_inlay_hints = set_inlay_hints,
})
