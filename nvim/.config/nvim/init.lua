-- Set leader key before any configs are loaded
vim.keymap.set('n', '<SPACE>', '<Nop>', { noremap = true })
vim.g.mapleader = ' '

-- Bootstrap and setup lazy.nvim
require('lazy-bootstrap')
require('lazy').setup('plugins')

-- Set colorscheme after plugins are loaded
vim.opt.background = 'dark'
vim.cmd('colorscheme catppuccin')

-- Load plugin configurations
require('config.nvim-tree')
require('config.blamer')
require('config.telescope')
require('config.neoformat')
require('config.lualine')
require('config.aerial')
require('config.completion')

-- Load user preferences
require('config.preferences')

-- Load LSP configuration
require('lsp')

-- Load treesitter config, but don't fail if module isn't ready
local ok, err = pcall(require, 'config.treesitter')
if not ok then
  vim.notify('Treesitter config failed to load (may need :TSUpdate): ' .. tostring(err), vim.log.levels.WARN)
end
