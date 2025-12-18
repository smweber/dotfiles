let g:nvim_config_root = stdpath('config')
let g:config_file_list = [
\ 'plugins.vim',
\ 'prefs.vim'
\ ]

" Set leader before any configs are loaded
nnoremap <SPACE> <Nop>
let mapleader=' '

for f in g:config_file_list
    execute 'source ' . g:nvim_config_root . '/' . f
endfor

" Load Lua configurations
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

