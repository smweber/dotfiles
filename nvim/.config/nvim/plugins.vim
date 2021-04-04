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

" Themes
Plug 'rakr/vim-one'
Plug 'joshdick/onedark.vim'

" Development
Plug 'ctrlpvim/ctrlp.vim'   " File opening
Plug 'sheerun/vim-polyglot' " A collection of language packs
Plug 'tpope/vim-sleuth'     " Heuristically set buffer options
"Plug 'w0rp/ale'             " Async linting

" CoC (LSP support for 'intellisense')
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" Ruby/Rails
Plug 'tpope/vim-rails'
Plug 'vim-ruby/vim-ruby'

" Writing
Plug 'junegunn/goyo.vim'
call plug#end()


"---------- Config Packages ----------
map ` :NERDTreeToggle<CR>
let NERDTreeMinimalUI = 1
let NERDTreeDirArrows = 1

" (Note: CoC config is separate, in coc-config.vim)
