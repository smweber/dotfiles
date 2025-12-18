-- Treesitter configuration for syntax and text objects

require('nvim-treesitter').setup({
  -- Install parsers for your languages
  ensure_installed = {
    'go',
    'typescript',
    'javascript',
    'tsx',
    'ruby',
    'python',
    'lua',
    'vim',
    'vimdoc',
    'gleam',
    'elixir',
    'erlang',
    'sql',
  },

  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = false,

  -- Automatically install missing parsers when entering buffer
  auto_install = true,

  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },

  -- Note: textobjects config removed because nvim-treesitter-textobjects
  -- is incompatible with latest nvim-treesitter. Can add alternative solution later.
})
