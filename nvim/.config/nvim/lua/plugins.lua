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
  {
    'algmyr/vcsigns.nvim',
    dependencies = { 'algmyr/vclib.nvim' },
    config = function()
      require('vcsigns').setup {
        target_commit = 1,  -- Nice default for jj with new+squash flow.
      }

      -- Keybindings
      local function map(mode, lhs, rhs, desc, opts)
        local options = { noremap = true, silent = true, desc = desc }
        if opts then options = vim.tbl_extend('force', options, opts) end
        vim.keymap.set(mode, lhs, rhs, options)
      end

      map('n', '[r', function() require('vcsigns.actions').target_older_commit(0, vim.v.count1) end, 'Move diff target back')
      map('n', ']r', function() require('vcsigns.actions').target_newer_commit(0, vim.v.count1) end, 'Move diff target forward')
      map('n', '[c', function() require('vcsigns.actions').hunk_prev(0, vim.v.count1) end, 'Go to previous hunk')
      map('n', ']c', function() require('vcsigns.actions').hunk_next(0, vim.v.count1) end, 'Go to next hunk')
      map('n', '[C', function() require('vcsigns.actions').hunk_prev(0, 9999) end, 'Go to first hunk')
      map('n', ']C', function() require('vcsigns.actions').hunk_next(0, 9999) end, 'Go to last hunk')
      map('n', '<leader>su', function() require('vcsigns.actions').hunk_undo(0) end, 'Undo hunks under cursor')
      map('v', '<leader>su', function() require('vcsigns.actions').hunk_undo(0) end, 'Undo hunks in range')
      map('n', '<leader>sd', function() require('vcsigns.actions').toggle_hunk_diff(0) end, 'Show hunk diffs inline in the current buffer')
      map('n', '<leader>sf', function() require('vcsigns.fold').toggle(0) end, 'Fold outside hunks')
    end,
  },
  -- VCS diffs with diftastic
  -- See https://github.com/clabby/difftastic.nvim?tab=readme-ov-file#requirements for installing fork of difft
  {
    "clabby/difftastic.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    config = function()
        require("difftastic-nvim").setup({
            download = true, -- Auto-download pre-built binary
        })
    end,
  },

  -- Themes
  { 'catppuccin/nvim', name = 'catppuccin' },
  'joshdick/onedark.vim',
  'rakr/vim-one',

  -- Development
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
    lazy = false,
    build = ':TSUpdate',
  },
  { -- needed since nvim-treesitter rewrite doesn't support autoinstall
    'mks-h/treesitter-autoinstall.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      require('treesitter-autoinstall').setup()
    end
  },

  -- Autoformatting
  'stevearc/conform.nvim',

  -- Writing
  'junegunn/goyo.vim',

  -- AI
  {
    "Exafunction/windsurf.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "hrsh7th/nvim-cmp",
    },
    config = function()
      require("codeium").setup({
        enable_cmp_source = false,
        virtual_text = {
          enabled = true,
          map_keys = true,
          key_bindings = {
            accept = "<C-y>",  -- Ctrl-Y to accept suggestions
            next = "<M-]>",    -- Alt-] for next suggestion
            prev = "<M-[>",    -- Alt-[ for previous suggestion
            clear = "<C-]>",   -- Ctrl-] to dismiss
          }
        }
      })
    end
  },
}
