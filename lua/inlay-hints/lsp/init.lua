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

function Server:get_hints(bufnr, callback)
  self.__fns.get_hints(bufnr, callback)
end

function Server:on_attach(server, bufnr)
  if server.name ~= self.name then
    return
  end
  if self.__fns.on_attach then
    self.__fns.on_attach(server, bufnr)
  end

  local lib = require('inlay-hints')
  lib.setup_autocmd(bufnr, server.name)
  lib.set_inlay_hints(bufnr, server.name)
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
  tsserver = 'tsserver',
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

function M.get_hints(name, bufnr, callback)
  if not name then
    for _, server in ipairs(vim.lsp.buf_get_clients(bufnr or 0)) do
      M.get_hints(server.name, bufnr, callback)
    end
  else
    local server = M.get(name)
    if server then
      server:get_hints(bufnr, callback)
    else
      callback(false)
    end
  end
end

return M
