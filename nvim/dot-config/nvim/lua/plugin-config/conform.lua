-- conform.nvim configuration for code formatting
require('conform').setup({
  formatters_by_ft = {
    go = { 'goimports' },
    -- Gleam uses LSP formatting (via lsp_fallback below)
  },

  -- Format on save
  format_on_save = function(bufnr)
    -- Disable format on save for files you don't want formatted
    -- if vim.bo[bufnr].filetype == 'some_type' then
    --   return
    -- end

    return {
      timeout_ms = 500,
      lsp_fallback = true,
    }
  end,

  -- Custom formatters (if needed)
  formatters = {
    goimports = {
      command = 'goimports',
      stdin = true,
    },
  },
})

-- Manual format keymap was already set in lsp/keymaps.lua (<leader>f)
-- But we can override it here to use conform instead of LSP
vim.keymap.set({ 'n', 'v' }, '<leader>f', function()
  require('conform').format({
    lsp_fallback = true,
    async = false,
    timeout_ms = 500,
  })
end, { desc = 'Format buffer' })
