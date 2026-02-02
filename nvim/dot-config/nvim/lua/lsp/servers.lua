-- Language server configurations using Neovim 0.11+ native API
-- nvim-lspconfig provides server-specific configs that vim.lsp.config auto-discovers

local lsp_keymaps = require('lsp.keymaps')

-- Capabilities for nvim-cmp
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- Common on_attach function
local on_attach = lsp_keymaps.on_attach

-- ==================== Go (gopls) ====================
-- Using daemon mode like coc-go for better memory efficiency
vim.lsp.config('gopls', {
  cmd = { 'gopls', '-remote=auto' }, -- Daemon mode: shares one gopls process across sessions
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
        shadow = false,
      },
      staticcheck = false,
      gofumpt = true,
      hints = {
        parameterNames = true,
        constantValues = true,
        assignVariableTypes = false,
        compositeLiteralFields = false,
        compositeLiteralTypes = false,
        functionTypeParameters = false,
        rangeVariableTypes = false,
      },
      directoryFilters = {
        "-vendor",
        "-node_modules",
        "-.git",
        "-dist",
        "-build",
      },
    },
  },
})
vim.lsp.enable('gopls')

-- ==================== TypeScript/JavaScript (ts_ls) ====================
vim.lsp.config('ts_ls', {
  on_attach = function(client, bufnr)
    -- Disable ts_ls formatting in favor of prettier or other formatters
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
    on_attach(client, bufnr)
  end,
  capabilities = capabilities,
  settings = {
    typescript = {
      inlayHints = {
        includeInlayParameterNameHints = 'all',
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
    },
    javascript = {
      inlayHints = {
        includeInlayParameterNameHints = 'all',
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
    },
  },
})
vim.lsp.enable('ts_ls')

-- ==================== Ruby (Sorbet) ====================
vim.lsp.config('sorbet', {
  cmd = { 'srb', 'tc', '--lsp', '--enable-all-experimental-lsp-features' },
  filetypes = { 'ruby' },
  root_markers = { 'sorbet/config' },
  on_attach = on_attach,
  capabilities = capabilities,
})
vim.lsp.enable('sorbet')

-- ==================== Python (basedpyright) ====================
vim.lsp.config('basedpyright', {
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    basedpyright = {
      analysis = {
        typeCheckingMode = 'basic',
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = 'workspace',
      },
    },
  },
})
vim.lsp.enable('basedpyright')

-- ==================== Gleam ====================
vim.lsp.config('gleam', {
  on_attach = on_attach,
  capabilities = capabilities,
})
vim.lsp.enable('gleam')

-- ==================== Elixir (elixir-ls) ====================
vim.lsp.config('elixirls', {
  on_attach = on_attach,
  capabilities = capabilities,
})
vim.lsp.enable('elixirls')

-- ==================== Erlang ====================
vim.lsp.config('erlangls', {
  on_attach = on_attach,
  capabilities = capabilities,
})
vim.lsp.enable('erlangls')

-- ==================== SQL (sqls) ====================
vim.lsp.config('sqls', {
  on_attach = on_attach,
  capabilities = capabilities,
})
vim.lsp.enable('sqls')
