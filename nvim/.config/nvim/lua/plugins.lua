-- lazy.nvim plugin specification
return {
  -- Change Behaviour
  'tpope/vim-sensible',
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
  },
  {
    'christoomey/vim-tmux-navigator',
    cmd = {
      'TmuxNavigateLeft',
      'TmuxNavigateDown',
      'TmuxNavigateUp',
      'TmuxNavigateRight',
      'TmuxNavigatePrevious',
      'TmuxNavigatorProcessList',
    },
    keys = {
      { '<c-h>', '<cmd><C-U>TmuxNavigateLeft<cr>' },
      { '<c-j>', '<cmd><C-U>TmuxNavigateDown<cr>' },
      { '<c-k>', '<cmd><C-U>TmuxNavigateUp<cr>' },
      { '<c-l>', '<cmd><C-U>TmuxNavigateRight<cr>' },
      { '<c-\\>', '<cmd><C-U>TmuxNavigatePrevious<cr>' },
    },
  },
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
  },
  'chrisbra/Colorizer',

  -- VCS Signs (for jj/git)
  'algmyr/vclib.nvim',
  'algmyr/vcsigns.nvim',

  -- Themes
  { 'catppuccin/nvim', name = 'catppuccin' },
  'joshdick/onedark.vim',
  'rakr/vim-one',

  -- Development
  {
    'junegunn/fzf',
    build = './install --bin',
  },
  'junegunn/fzf.vim',
  'tpope/vim-sleuth',
  'APZelos/blamer.nvim',

  -- LSP & Completion
  'neovim/nvim-lspconfig',
  {
    'hrsh7th/nvim-cmp',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',
    },
  },

  -- Symbol outline & fuzzy finder
  'stevearc/aerial.nvim',
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
  },

  -- Treesitter
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
  },

  -- Autoformatting (for Go)
  'sbdchd/neoformat',

  -- Writing
  'junegunn/goyo.vim',

  -- AI
  'Exafunction/windsurf.vim',
}
