local utils = require('inlay-hints.utils')

local function fix_range(range)
  local new_range = vim.tbl_deep_extend('force', {}, range)
  new_range.start.line = new_range.start.line + 1
  new_range.start.character = new_range.start.character + 1
  new_range['end'].line = new_range['end'].line + 1
  new_range['end'].character = new_range['end'].character + 1
  return new_range
end

local INVALID_CHARS = utils.split('\'"|!%&/()=?`^[]{}#-.:,;<>@+* ')

local function is_valid_char(ch)
  return not vim.tbl_contains(INVALID_CHARS, ch)
end

local function get_ident(bufnr, range)
  local text = utils.get_text(bufnr, range)

  if not text or string.len(text) == 0 then
    return
  end

  for _, ch in ipairs(utils.split(text)) do
    if not is_valid_char(ch) then
      return
    end
  end
  return text
end

-- [1]: error
-- [2]: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#inlayHintParams
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

  local save_hints = { variables = {}, returns = {}, infos = {} }

  for _, hint in ipairs(hints) do
    if hint.kind == 1 then
      local range = fix_range(hint.data.position)
      local ident = get_ident(info.bufnr, range)

      if not ident then
        local _hint = {
          type = hint.tooltip,
          range = range,
        }
        table.insert(save_hints.returns, _hint)
      else
        local _hint = {
          type = hint.tooltip,
          name = ident,
          range = range,
        }

        table.insert(save_hints.variables, _hint)
      end
    elseif hint.kind == 2 then
      -- paramter names
    else
      local _hint = {
        range = {
          ['end'] = {
            line = hint.position.line + 1,
            character = hint.position.character + 1,
          },
        },
        type = hint.tooltip,
      }

      table.insert(save_hints.infos, _hint)
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
    'textDocument/inlayHint',
    utils.get_params(bufnr),
    callback_handler(callback)
  )
end

local function on_server_start(_, result)
  local bufnr = vim.api.nvim_get_current_buf()

  local server = utils.buf_get_lsp(bufnr, 'rust_analyzer')
  if server and utils.server_has_inlay_hints(server) then
    require('inlay-hints').set_inlay_hints(bufnr, 'rust_analyzer')
  end
end

local function lsp_options()
  return {
    capabilities = {
      experimental = {
        serverStatusNotification = true,
      },
    },
  }
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
  lsp_options = lsp_options,
  lsp_handlers = lsp_handlers,
  get_hints = get_hints,
})
