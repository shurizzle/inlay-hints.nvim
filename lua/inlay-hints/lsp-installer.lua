local M = {}

function M.setup(server, opts)
  opts = require('inlay-hints').lsp_options(server.name, opts)
  return server:setup(opts)
end

function M.on_server_ready(server)
  return M.setup(server)
end

return M
