-- nvim-tree configuration

-- Disable netrw (recommended by nvim-tree)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require('nvim-tree').setup({
  -- Sort folders before files
  sort_by = "case_sensitive",

  -- Show hidden files
  filters = {
    dotfiles = false,
  },

  -- Customize appearance
  renderer = {
    group_empty = true,
    icons = {
      show = {
        git = true,
        folder = true,
        file = true,
        folder_arrow = true,
      },
    },
  },

  -- Update focused file in tree
  update_focused_file = {
    enable = true,
    update_root = false,
  },

  -- Window behavior
  view = {
    width = 30,
  },
})

-- Toggle function similar to old NERDTree behavior
vim.keymap.set('n', '`', function()
  require('nvim-tree.api').tree.toggle({ find_file = true, focus = true })
end, { silent = true, desc = 'Toggle nvim-tree' })
