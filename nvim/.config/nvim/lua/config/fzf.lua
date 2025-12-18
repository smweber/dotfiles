-- fzf configuration
vim.g.fzf_layout = { window = { width = 0.9, height = 0.9, relative = 'editor' } }

-- fzf keybindings
vim.keymap.set('n', '<C-P>', ':Files<CR>', { noremap = true })
vim.keymap.set('n', '<Leader>r', ':RG<CR>', { noremap = true })
