-- Aerial.nvim configuration (Vista.vim replacement)

require('aerial').setup({
  -- Priority list of preferred backends for aerial
  backends = { 'lsp', 'treesitter', 'markdown', 'man' },

  -- How to open the aerial window
  layout = {
    max_width = { 50, 0.2 },
    width = 50,
    min_width = 30,
    default_direction = 'prefer_right',
  },

  -- Filter kinds (matching Vista's ignore_kinds for Variable)
  filter_kind = {
    "Class",
    "Constructor",
    "Enum",
    "Function",
    "Interface",
    "Method",
    "Module",
    "Struct",
    -- Explicitly exclude Variable (like Vista config)
    -- "Variable",
  },

  -- Show box drawing characters for the tree hierarchy
  show_guides = true,

  -- Keymaps in aerial window
  keymaps = {
    ["?"] = "actions.show_help",
    ["g?"] = "actions.show_help",
    ["<CR>"] = "actions.jump",
    ["<2-LeftMouse>"] = "actions.jump",
    ["<C-v>"] = "actions.jump_vsplit",
    ["<C-s>"] = "actions.jump_split",
    ["p"] = "actions.scroll",
    ["<C-j>"] = "actions.down_and_scroll",
    ["<C-k>"] = "actions.up_and_scroll",
    ["{"] = "actions.prev",
    ["}"] = "actions.next",
    ["[["] = "actions.prev_up",
    ["]]"] = "actions.next_up",
    ["q"] = "actions.close",
    ["o"] = "actions.tree_toggle",
    ["za"] = "actions.tree_toggle",
    ["O"] = "actions.tree_toggle_recursive",
    ["zA"] = "actions.tree_toggle_recursive",
    ["l"] = "actions.tree_open",
    ["zo"] = "actions.tree_open",
    ["L"] = "actions.tree_open_recursive",
    ["zO"] = "actions.tree_open_recursive",
    ["h"] = "actions.tree_close",
    ["zc"] = "actions.tree_close",
    ["H"] = "actions.tree_close_recursive",
    ["zC"] = "actions.tree_close_recursive",
    ["zr"] = "actions.tree_increase_fold_level",
    ["zR"] = "actions.tree_open_all",
    ["zm"] = "actions.tree_decrease_fold_level",
    ["zM"] = "actions.tree_close_all",
    ["zx"] = "actions.tree_sync_folds",
    ["zX"] = "actions.tree_sync_folds",
  },

  -- Automatically set up buffer-local keymaps on attach
  on_attach = function(bufnr)
    -- Optional: Set up buffer-local keymaps for navigation
    vim.keymap.set('n', '{', '<cmd>AerialPrev<CR>', { buffer = bufnr })
    vim.keymap.set('n', '}', '<cmd>AerialNext<CR>', { buffer = bufnr })
  end,
})

-- Keymaps (matching Vista keybindings from plugins.vim)
-- <Leader>vv: Toggle Aerial (like Vista!!)
vim.keymap.set('n', '<Leader>vv', '<cmd>AerialToggle!<CR>', { desc = 'Toggle Aerial' })

-- <Leader>vf and <C-Q>: Aerial finder with Telescope
vim.keymap.set('n', '<Leader>vf', '<cmd>Telescope aerial<CR>', { desc = 'Aerial finder (Telescope)' })
vim.keymap.set('n', '<C-Q>', '<cmd>Telescope aerial<CR>', { desc = 'Aerial finder (Telescope)' })
