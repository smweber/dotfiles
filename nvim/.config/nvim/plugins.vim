"---------- Plug Package Management ----------
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

" Elixir
Plug 'slashmili/alchemist.vim'
" Haskell
Plug 'eagletmt/neco-ghc'
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
