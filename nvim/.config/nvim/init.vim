let g:nvim_config_root = stdpath('config')

" Set leader before any configs are loaded
nnoremap <SPACE> <Nop>
let mapleader=' '

" Load preferences
execute 'source ' . g:nvim_config_root . '/prefs.vim'

" Bootstrap and setup lazy.nvim
lua require('lazy-bootstrap')
lua require('lazy').setup('plugins')

" Set colorscheme after plugins are loaded
set background=dark
colorscheme catppuccin

" Load plugin configurations
lua require('config.nvim-tree')
lua require('config.blamer')
lua require('config.telescope')
lua require('config.neoformat')
lua require('config.vcsigns')
lua require('config.airline')

" Load LSP and completion configurations
lua require('lsp')
lua require('completion')
lua require('aerial-config')
lua << EOF
-- Load treesitter config, but don't fail if module isn't ready
local ok, err = pcall(require, 'treesitter-config')
if not ok then
  vim.notify('Treesitter config failed to load (may need :TSUpdate): ' .. tostring(err), vim.log.levels.WARN)
end
EOF
