local M = {}

function M.setup(name, opts)
  return require('lspconfig')[name].setup(M.options(name, opts))
end

function M.options(name, opts)
  return require('inlay-hints').lsp_options(name, opts)
end

return M
