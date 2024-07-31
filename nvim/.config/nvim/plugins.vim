"---------- Plug Package Management ----------
" (Auto-install Plug if it's not installed)
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin()

" Change Behaviour
Plug 'tpope/vim-sensible'
Plug 'vim-airline/vim-airline'
Plug 'airblade/vim-gitgutter'
Plug 'christoomey/vim-tmux-navigator'
Plug 'scrooloose/nerdtree'
Plug 'chrisbra/Colorizer'

" Themes
Plug 'catppuccin/nvim', { 'as': 'catppuccin' }
Plug 'joshdick/onedark.vim'
Plug 'rakr/vim-one'

" Development
"Plug 'ctrlpvim/ctrlp.vim'   " File opening
Plug 'junegunn/fzf'         " File opening and more (basic fzf wrapper)
Plug 'junegunn/fzf.vim'     " (Need this one too for nice functionality)
Plug 'sheerun/vim-polyglot' " A collection of language packs
Plug 'tpope/vim-sleuth'     " Heuristically set buffer options
"Plug 'w0rp/ale'             " Async linting
Plug 'APZelos/blamer.nvim'

" CoC (LSP support for 'intellisense')
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'liuchengxu/vista.vim'

" Autoformatting (for Go)
Plug 'sbdchd/neoformat'

" Ruby/Rails
"Plug 'tpope/vim-rails'
"Plug 'vim-ruby/vim-ruby'

" Writing
Plug 'junegunn/goyo.vim'

" AI
"Plug 'codota/tabnine-nvim', { 'do': './dl_binaries.sh' }
Plug 'github/copilot.vim'
" CodeGPT
Plug 'nvim-lua/plenary.nvim'
Plug 'MunifTanjim/nui.nvim'
Plug 'dpayne/CodeGPT.nvim'
call plug#end()


"---------- Config Packages ----------
let NERDTreeMinimalUI = 1
let NERDTreeDirArrows = 1
function! ToggleNERDTree()
    if exists("b:NERDTree") " && b:NERDTreeType ==# 'primary'
        wincmd p
        execute "NERDTreeClose"
    else
        execute "NERDTreeFind"
    endif
endfunction
nnoremap <silent> ` :call ToggleNERDTree()<CR>

" Enable blamer
let g:blamer_enabled = 1

" Vista config
let g:vista_default_executive = 'coc'
let g:vista_ignore_kinds = ['Variable']
let g:vista_sidebar_width = 50
"let g:vista_fzf_preview = ['right:50%']
function! NearestMethodOrFunction() abort
  return get(b:, 'vista_nearest_method_or_function', '')
endfunction
set statusline+=%{NearestMethodOrFunction()}

" fzf layout
let fzf_layout = { 'window': { 'width': 0.9, 'height': 0.9, 'relative': 'editor' } }

" fzf and vista keybindings
nnoremap <C-P> :Files<Cr>
nnoremap <Leader>r :RG<Cr>
nnoremap <C-Q> :Vista finder<Cr>
nnoremap <Leader>vv :Vista!!<Cr>
nnoremap <Leader>vf :Vista finder<Cr>

" neoformat
let g:neoformat_go_goimports = {
\ 'exe': 'goimports',
\ 'stdin': 1
\ }
let g:neoformat_enabled_go = ['goimports']
augroup fmt
  autocmd!
  autocmd BufWritePre *.go undojoin | Neoformat
augroup END


" (Note: CoC config is separate, in coc-config.vim)
