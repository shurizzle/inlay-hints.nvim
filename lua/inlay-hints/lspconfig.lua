local M = {}

function M.setup(name, opts)
  return require('inlay-hints').lsp_setup(name, opts)
end

function M.options(name, opts)
  return require('inlay-hints').lsp_options(name, opts)
end

return M
