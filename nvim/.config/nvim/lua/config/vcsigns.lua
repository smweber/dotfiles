-- VCSigns configuration and keybindings
require('vcsigns').setup {
  target_commit = 1,  -- Nice default for jj with new+squash flow.
}

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
