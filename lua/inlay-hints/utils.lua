local M = {}

function M.get_params()
  return { textDocument = vim.lsp.util.make_text_document_params() }
end

function M.make_handler(fn)
  return function(...)
    local config_or_client_id = select(4, ...)
    if type(config_or_client_id) ~= 'number' then
      fn(...)
    else
      local err = select(1, ...)
      local method = select(2, ...)
      local result = select(3, ...)
      local client_id = select(4, ...)
      local bufnr = select(5, ...)
      local config = select(6, ...)
      fn(
        err,
        result,
        { method = method, client_id = client_id, bufnr = bufnr },
        config
      )
    end
  end
end

function M.request(bufnr, method, params, handler)
  return vim.lsp.buf_request(bufnr, method, params, M.make_handler(handler))
end

function M.get_text(bufnr, range)
  local lines = vim.api.nvim_buf_get_lines(
    bufnr,
    range.start.line,
    range['end'].line + 1,
    false
  )

  if #lines == 0 then
    return lines
  end

  lines[1] = string.sub(lines[1], range.start.character + 1)
  lines[#lines] = string.sub(
    lines[#lines],
    1,
    range['end'].character - range.start.character
  )

  return table.concat(lines, '\n')
end

function M.concat_functions(a, b)
  return function(...)
    a(...)
    return b(...)
  end
end

function M.deep_extend(policy, ...)
  local result = {}

  local function helper(policy, k, a, b)
    if type(a) == 'function' and type(b) == 'function' then
      return M.concat_functions(a, b)
    elseif type(a) == 'table' and type(b) == 'table' then
      return M.deep_extend(policy, a, b)
    else
      if policy == 'error' then
        error(
          'Key '
            .. vim.inspect(k)
            .. ' is already present with value '
            .. vim.inspect(b)
        )
      elseif policy == 'force' then
        return b
      else
        return a
      end
    end
  end

  for _, t in ipairs({ ... }) do
    for k, v in pairs(t) do
      if result[k] ~= nil then
        result[k] = helper(policy, k, result[k], v)
      else
        result[k] = v
      end
    end
  end

  return result
end

function M.buf_has_lsp(bufnr, name)
  for _, server in ipairs(vim.lsp.buf_get_clients(bufnr)) do
    if server.name == name then
      return true
    end
  end

  return false
end

return M
