---- Custom LSP handlers for better UI

-- Better hover handler with borders
vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(
  vim.lsp.handlers.hover, {
    border = 'rounded',
  }
)

-- Better signature help with borders
vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(
  vim.lsp.handlers.signature_help, {
    border = 'rounded',
  }
)
