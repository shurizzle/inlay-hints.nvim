local M = {}

local utils = require('inlay-hints.utils')

local server_names = {
  rust_analyzer = 'rust_analyzer',
}

local servers = {}

local function create_cache(name)
  if not server_names[name] then
    return
  end

  local server = require('inlay-hints.lsp.' .. server_names[name])

  if not server.lsp_handlers then
    server.lsp_handlers = function()
      return {}
    end
  end

  if not server.lsp_options then
    server.lsp_options = function()
      return {}
    end
  end

  if not server.set_inlay_hints then
    server.set_inlay_hints = function() end
  end

  if not server.on_attach then
    function server.on_attach(s, bufnr)
      if s.name ~= name then
        return
      end

      require('inlay-hints').setup_autocmd(bufnr, s.name)
      server.set_inlay_hints(bufnr)
    end
  end

  server._lsp_handlers = server.lsp_handlers
  function server.lsp_handlers(opts)
    return utils.deep_extend('force', opts or {}, server._lsp_handlers())
  end

  server._lsp_options = server.lsp_options
  function server.lsp_options(opts)
    opts = utils.deep_extend('force', opts or {}, server._lsp_options())
    opts.handlers = server.lsp_handlers(opts.handlers)
    if type(opts.on_attach) == 'function' then
      opts.on_attach = utils.concat_functions(opts.on_attach, server.on_attach)
    else
      opts.on_attach = server.on_attach
    end

    return opts
  end

  servers[name] = server
end

function M.get(name)
  create_cache(name)
  return servers[name]
end

function M.on_attach(s, bufnr)
  local server = M.get(s.name)
  if server and server.on_attach then
    return server.on_attach(s, bufnr)
  end
end

function M.lsp_handlers(name, opts)
  local server = M.get(name)
  if server then
    return server.lsp_handlers(opts)
  end
  return opts
end

function M.lsp_options(name, opts)
  local server = M.get(name)
  if server then
    return server.lsp_options(opts)
  end
  return opts
end

function M.set_inlay_hints(bufnr, name)
  local server = M.get_server(name)
  if server then
    server.set_inlay_hints(bufnr)
  end
end

return M
