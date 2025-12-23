-- LSP keybindings module

local M = {}

-- Global diagnostic keymaps (don't require LSP)
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev,
  { desc = 'Go to previous diagnostic', silent = true })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next,
  { desc = 'Go to next diagnostic', silent = true })

-- LSP attach function - called when LSP attaches to buffer
M.on_attach = function(client, bufnr)
  local opts = { buffer = bufnr, silent = true }

  -- Navigation
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition,
    vim.tbl_extend('force', opts, { desc = 'Go to definition' }))
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration,
    vim.tbl_extend('force', opts, { desc = 'Go to declaration' }))
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation,
    vim.tbl_extend('force', opts, { desc = 'Go to implementation' }))
  vim.keymap.set('n', 'gr', vim.lsp.buf.references,
    vim.tbl_extend('force', opts, { desc = 'Show references' }))

  -- Hover documentation
  vim.keymap.set('n', 'K', vim.lsp.buf.hover,
    vim.tbl_extend('force', opts, { desc = 'Show hover documentation' }))

  -- Signature help
  vim.keymap.set('i', '<C-k>', vim.lsp.buf.signature_help,
    vim.tbl_extend('force', opts, { desc = 'Signature help' }))

  -- Rename
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename,
    vim.tbl_extend('force', opts, { desc = 'Rename symbol' }))

  -- Format (moved to conform.lua)
  -- vim.keymap.set({ 'n', 'x' }, '<leader>f', function()
  --   vim.lsp.buf.format({ async = false })
  -- end, vim.tbl_extend('force', opts, { desc = 'Format code' }))

  -- Code actions
  vim.keymap.set({ 'n', 'x' }, '<leader>ca', vim.lsp.buf.code_action,
    vim.tbl_extend('force', opts, { desc = 'Code action' }))

  -- Enable inlay hints if supported (Neovim 0.10+)
  if client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end

  -- Highlight symbol under cursor (like CoC's CursorHold behavior)
  if client.server_capabilities.documentHighlightProvider then
    local group = vim.api.nvim_create_augroup('LSPDocumentHighlight', { clear = false })
    vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
      group = group,
      buffer = bufnr,
      callback = vim.lsp.buf.document_highlight,
    })
    vim.api.nvim_create_autocmd('CursorMoved', {
      group = group,
      buffer = bufnr,
      callback = vim.lsp.buf.clear_references,
    })
  end
end

return M
