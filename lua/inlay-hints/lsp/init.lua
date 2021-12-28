local M = {}

local utils = require('inlay-hints.utils')

local Server = {}
Server.__index = Server

function Server:new(server)
  local s = { __fns = server }
  setmetatable(s, Server)
  return s
end

function Server:lsp_handlers(opts)
  if self.__fns.lsp_handlers then
    return utils.deep_extend('force', opts or {}, self.__fns.lsp_handlers())
  else
    return opts
  end
end

function Server:force_set_inlay_hints(bufnr, filter)
  if self.__fns.set_inlay_hints then
    self.__fns.set_inlay_hints(bufnr, filter)
  end
end

function Server:set_inlay_hints(bufnr, filter)
  if
    (vim.g.inlay_hints_enabled or 1) ~= 0
    and vim.fn.getbufvar(bufnr or 0, 'inlay_hints_enabled', 1) ~= 0
  then
    self:force_set_inlay_hints(bufnr, filter)
  end
end

function Server:on_attach(server, bufnr)
  if server.name ~= self.name then
    return
  end
  if self.__fns.on_attach then
    self.__fns.on_attach(server, bufnr)
  end

  require('inlay-hints').setup_autocmd(bufnr, server.name)
  self:set_inlay_hints(bufnr)
end

function Server:lsp_options(opts)
  if self.__fns.lsp_options then
    opts = utils.deep_extend('force', opts or {}, self.__fns.lsp_options())
  end

  opts.handlers = self:lsp_handlers(opts.handlers)

  local on_attach = (function(server)
    return function(...)
      return server:on_attach(...)
    end
  end)(self)

  if type(opts.on_attach) == 'function' then
    opts.on_attach = utils.concat_functions(opts.on_attach, on_attach)
  else
    opts.on_attach = on_attach
  end

  return opts
end

local server_names = {
  rust_analyzer = 'rust_analyzer',
}

M.Server = Server

function M.get(name)
  if not server_names[name] then
    return
  end

  local server = require('inlay-hints.lsp.' .. server_names[name])
  if server then
    server.name = name
  end

  return server
end

function M.on_attach(s, bufnr)
  local server = M.get(s.name)
  if server then
    return server:on_attach(s, bufnr)
  end
end

function M.lsp_handlers(name, opts)
  local server = M.get(name)
  if server then
    return server:lsp_handlers(opts)
  end
  return opts
end

function M.lsp_options(name, opts)
  local server = M.get(name)
  if server then
    return server:lsp_options(opts)
  end
  return opts
end

local function call_inlay_hints(method, bufnr, name, filter)
  if not name then
    for _, server in ipairs(vim.lsp.buf_get_clients(bufnr)) do
      M[method](bufnr, server.name, filter)
    end
  else
    local server = M.get(name)
    if server then
      Server[method](server, bufnr, filter)
    end
  end
end

function M.set_inlay_hints(bufnr, name, filter)
  return call_inlay_hints('set_inlay_hints', bufnr, name, filter)
end

function M.force_set_inlay_hints(bufnr, name, filter)
  return call_inlay_hints('force_set_inlay_hints', bufnr, name, filter)
end

return M
