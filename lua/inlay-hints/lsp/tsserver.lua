local utils = require('inlay-hints.utils')

local function fix_position(pos)
  local new_pos = vim.tbl_deep_extend('force', {}, pos)
  new_pos.character = new_pos.character
  new_pos.line = new_pos.line + 1
  return new_pos
end

local function _split(str)
  if #str > 0 then
    return str:sub(1, 1), _split(str:sub(2))
  end
end

local function split(str)
  return { _split(str) }
end

local INVALID_CHARS = split('\'"|!%&/()=?`^[]{}#-.:,;<>@+* ')

local function is_valid_char(ch)
  return not vim.tbl_contains(INVALID_CHARS, ch)
end

local function get_last_word(line)
  local res = ''

  for i = #line, 1, -1 do
    local ch = string.sub(line, i, i)

    if is_valid_char(ch) then
      res = ch .. res
    else
      if #res == 0 then
        res = nil
      end
      return res
    end
  end

  return res
end

-- [1]: error
-- [2]: v
--   kind: Type, text: ": type", position
--   kind: Parameter, text: name, position
--   kind: Enum, text: ???, position
-- [3]: {bufnr, client_id, method, params={textDocument={uri}}}
-- [4]: config
local function handler(error, hints, info, _, callback)
  hints = hints.inlayHints
  _G.last_coso = hints
  if error then
    callback(error)
    return
  end

  if vim.api.nvim_get_current_buf() ~= info.bufnr then
    return
  end

  local save_hints = { variables = {}, returns = {} }
  local visited_positions = {}

  for _, hint in ipairs(hints) do
    if hint.kind == 'Type' then
      local pos = fix_position(hint.position)

      local name
      local key = tostring(pos.line) .. tostring(pos.character)

      if visited_positions[key] then
        name = nil
      else
        name = vim.api.nvim_buf_get_lines(bufnr, pos.line - 1, pos.line, false)
        name = name[1]
        name = string.sub(name, 1, pos.character)
        name = get_last_word(name)
        visited_positions[key] = true
      end

      local range = {
        ['end'] = { line = pos.line, character = pos.character },
      }
      if name then
        range.start = { line = pos.line, character = pos.character - #name }
      else
        range.start = { line = pos.line, character = pos.character }
      end
      local type = string.sub(hint.text, 3)

      if name then
        table.insert(save_hints.variables, {
          type = type,
          name = name,
          range = range,
        })
      else
        table.insert(save_hints.returns, {
          type = type,
          range = range,
        })
      end
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
    'typescript/inlayHints',
    utils.get_params(bufnr),
    callback_handler(callback)
  )
end

local function lsp_options()
  return {
    init_options = {
      hostInfo = 'neovim',
      preferences = {
        includeInlayParameterNameHints = 'none',
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = false,
      },
    },
  }
end

return require('inlay-hints.lsp').Server:new({
  get_hints = get_hints,
  lsp_options = lsp_options,
})
