# inlay-hints.nvim

A tool that shows inlay hints for auto-typed variables and returning types.

## Prerequisites

- neovim 0.5
- A nerdfont (Optional)

## Installation

### Plug

```viml
Plug 'shurizzle/inlay-hints.nvim'
```

### Packer

```lua
require('packer').startup(function()
  use { 'shurizzle/inlay-hints.nvim' }
end)
```

## Configuration

```lua
require'inlay-hints'.setup({
  ...options
})
```

### Default options

```lua
local default_options = {
  nerdfonts = true,
  render = {
    type_symbol = '‣ ',
    return_symbol = ' ',
    variable_separator = ': ',
    type_separator = ', ',
    return_separator = ', ',
    type_return_separator = ' ',
    highlight = 'Comment',
  },
}
```

- nerdfonts: boolean. Change type_symbol to '> ' and return_symbol to '< ' if they are not configured
- render.type_symbol: string. It precedes variables' hints.
- variable_separator: string. It separates variable name from its type.
- type_separator: string. It separates variables' hints.
- return_separator: string. It separates returns' hints.
- type_return_separator: string. It separates variables' and returns' hints.
- highlight: string. The highlight rule (you can define and extra one) to highlight text with.

## Usage

### Standalone

You can get LSP options with `require'inlay-hints'.lsp_options(server_name, your_lsp_options)` including `on_attach` function and LSP's callbacks or just `on_attach` function with `require'inlay-hints'.on_attach`.

### nvim-lspconfig

```lua
-- Get the options
require'inlay-hints.lspconfig'.options('rust_analyzer', {
  ...your_options
})

-- Setup the server
require'inlay-hints.lspconfig'.setup('rust_analyzer', {
  ...your_options
})
```

### nvim-lsp-installer

```lua
require'nvim-lsp-installer'.on_server_ready(function(server)
  -- Setup the server
  require'inlay-hints.lsp-installer'.setup(server, {
    ...your_options
  })
end)

-- or in the automatic way (useless I guess)
require'nvim-lsp-installer'.on_server_ready(require'inlay-hints.lsp-installer'.on_server_ready)
```

### rust-tools

```lua
require'inlay-hints.rust-tools'.setup({
  tools = {
    autoSetHints = false, -- Disable rust-tools' hints
  },
  server = {
    ...your_options
  }
})
```

### Complete example

From my nvim configuration:

```lua
require'nvim-lsp-installer'.on_server_ready(function(server)
  local cmp_nvim_lsp = require('cmp_nvim_lsp')
  local capabilities = cmp_nvim_lsp.update_capabilities(
    vim.lsp.protocol.make_client_capabilities()
  )

  local opts = {
    on_attach = require('config.plugins.lsp.handlers').on_attach,
    capabilities = capabilities,
  }

  if server.name == 'sumneko_lua' then
    local sumneko_opts = require('config.plugins.lsp.settings.sumneko_lua')
    opts = vim.tbl_deep_extend('force', sumneko_opts, opts)
  end

  if server.name == 'rust_analyzer' then
    require('inlay-hints.rust-tools').setup({
      tools = {
        autoSetHints = false,
      },
      server = vim.tbl_deep_extend(
        'force',
        server:get_default_options(),
        opts
      ),
    })
    server:attach_buffers()
  else
    require('inlay-hints.lsp-installer').setup(server, opts)
    server:setup(opts)
  end
end)
```

## Notes

inlay-hints.nvim doesn't override callback functions like `on_attach` or lsp callback, it just concat them together. (`'inlay-hints.utils'.concat_functions`)

## LSP supported

- rust_analyzer

---

Feel free to contribute.
