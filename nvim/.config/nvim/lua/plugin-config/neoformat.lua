-- neoformat configuration for Go
vim.g.neoformat_go_goimports = {
  exe = 'goimports',
  stdin = 1
}
vim.g.neoformat_enabled_go = { 'goimports' }

-- Auto-format Go files on save
vim.api.nvim_create_augroup('fmt', { clear = true })
vim.api.nvim_create_autocmd('BufWritePre', {
  group = 'fmt',
  pattern = '*.go',
  callback = function()
    -- Try to undojoin, but don't fail if nothing to join
    pcall(vim.cmd, 'undojoin')
    vim.cmd('Neoformat')
  end,
})
