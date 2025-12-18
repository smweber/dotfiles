-- NERDTree configuration
vim.g.NERDTreeMinimalUI = 1
vim.g.NERDTreeDirArrows = 1

function _G.ToggleNERDTree()
  if vim.b.NERDTree then
    vim.cmd('wincmd p')
    vim.cmd('NERDTreeClose')
  else
    vim.cmd('NERDTreeFind')
  end
end

vim.keymap.set('n', '`', '<cmd>lua ToggleNERDTree()<CR>', { silent = true })
