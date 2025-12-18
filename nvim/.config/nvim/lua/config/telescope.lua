-- Telescope configuration
local telescope = require('telescope')
local builtin = require('telescope.builtin')

telescope.setup({
  defaults = {
    -- Layout
    layout_strategy = 'horizontal',
    layout_config = {
      horizontal = {
        width = 0.9,
        height = 0.9,
        preview_width = 0.6,
      },
    },
    -- Behavior
    file_ignore_patterns = { "node_modules", ".git/" },
    -- UI
    borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
    -- Performance
    sorting_strategy = "ascending",
    prompt_prefix = "🔍 ",
    selection_caret = "❯ ",
  },
  pickers = {
    find_files = {
      hidden = true,  -- Show hidden files
    },
  },
})

-- Keybindings (matching old fzf keybindings)
vim.keymap.set('n', '<C-P>', builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<Leader>r', builtin.live_grep, { desc = 'Telescope live grep' })

-- Additional useful Telescope commands
vim.keymap.set('n', '<Leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<Leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
vim.keymap.set('n', '<Leader>fr', builtin.oldfiles, { desc = 'Telescope recent files' })
vim.keymap.set('n', '<Leader>fc', builtin.commands, { desc = 'Telescope commands' })
