-- Set leader key before any configs are loaded
vim.keymap.set('n', '<SPACE>', '<Nop>', { noremap = true })
vim.g.mapleader = ' '

-- Bootstrap and setup lazy.nvim
require('lazy-bootstrap')
require('lazy').setup('plugins')

-- Set colorscheme after plugins are loaded. Follow the light/dark mode
-- `toggledark` records in ~/.theme_mode ('true' = dark); default dark when the
-- file is absent or unreadable, so nvim never rewrites this tracked file.
local ok, theme = pcall(vim.fn.readfile, vim.fn.expand('~/.theme_mode'))
vim.opt.background = (ok and theme[1] == 'false') and 'light' or 'dark'
vim.cmd('colorscheme catppuccin')

-- Load user preferences first
require('preferences')

-- Load plugin configurations
require('plugin-config.nvim-tree')
require('plugin-config.blamer')
require('plugin-config.telescope')
require('plugin-config.conform')
require('plugin-config.lualine')
require('plugin-config.aerial')
require('plugin-config.completion')

-- Load LSP configuration
require('lsp')
