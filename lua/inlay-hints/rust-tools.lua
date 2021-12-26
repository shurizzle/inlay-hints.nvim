local M = {}

function M.setup(opts)
  opts.server = require('inlay-hints').lsp_options('rust_analyzer', opts.server)
  return require('rust-tools').setup(opts)
end

return M
