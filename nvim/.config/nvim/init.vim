let g:nvim_config_root = stdpath('config')
let g:config_file_list = [
\ 'plugins.vim',
\ 'prefs.vim',
\ 'coc-config.vim'
\ ]

" Set leader before any configs are loaded
nnoremap <SPACE> <Nop>
let mapleader=' '

for f in g:config_file_list
    execute 'source ' . g:nvim_config_root . '/' . f
endfor

