-- lazy.nvim plugin specification
return {
  -- Change Behaviour
  'tpope/vim-sensible',
  {
    'vim-airline/vim-airline',
    dependencies = { 'vim-airline/vim-airline-themes' },
  },
  'christoomey/vim-tmux-navigator',
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
