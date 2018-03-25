"---------- Plug Package Management ----------
call plug#begin()
" Change Behaviour
Plug 'tpope/vim-sensible'
Plug 'vim-airline/vim-airline'
Plug 'airblade/vim-gitgutter'
Plug 'christoomey/vim-tmux-navigator'
Plug 'Shougo/unite.vim'
Plug 'Shougo/vimfiler.vim', { 'on': 'VimFiler' }

" Themes
Plug 'rakr/vim-one'
Plug 'joshdick/onedark.vim'

" Development
Plug 'ctrlpvim/ctrlp.vim'   " File opening
Plug 'w0rp/ale'             " Async linting
Plug 'sheerun/vim-polyglot' " A collection of language packs
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' } " Async Completion
Plug 'tpope/vim-sleuth'     " Heuristically set buffer options

" Elm
Plug 'pbogut/deoplete-elm'
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
let g:ale_completion_enabled = 1
let g:deoplete#enable_at_startup = 1
map ` :VimFiler -explorer<CR>
map ~ :VimFilerCurrentDir -explorer -find<CR>
" Use tab to select autocomplete (from Deoplete currently)
inoremap <expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
let g:necoghc_use_stack = 1


" ---------- Scott's Preferences ----------
nnoremap <SPACE> <Nop>
let mapleader=' '
nmap <Leader>nn :set invnumber<CR>
let mapleader=' '
set nowrap
set expandtab           " Replaces actual tab with spaces (Ctrl-V tab for real tabs)
set shiftwidth=4        " Determines indent for >> and <<
set softtabstop=4       " Determines indent for <TAB>
set hlsearch            " Highlight search
set hls is ic scs       " Better search behaviour
set autoread            " Auto reload files that have changed outside vim
set scrolloff=2         " Start scrolling the viewport before the cursor reaches the last line
set swapfile
set dir=~/.tmp
set backupdir=~/.tmp
set splitbelow
set splitright
set number

" Colourscheme
"set termguicolors
colorscheme onedark
set background=dark
let g:airline_theme='onedark'

" Tab and window movement
nnoremap <c-k> <c-w><c-k>
nnoremap <c-j> <c-w><c-j>
nnoremap <c-h> <c-w><c-h>
nnoremap <c-l> <c-w><c-l>


" ---------- Writing and Wrapping Functions -----------
function! s:wrapIt()
    set wrap linebreak nolist
    nnoremap j gj
    nnoremap k gk
    nnoremap $ g$
    nnoremap ^ g^
endfunction

function! s:unWrapIt()
    set nowrap nolinebreak
    nunmap j
    nunmap k
    nunmap $
    nunmap ^
endfunction

function! s:goyo_enter()
    call s:wrapIt()
    let b:quitting = 0
    let b:quitting_bang = 0
    autocmd QuitPre <buffer> let b:quitting = 1
    cabbrev <buffer> q! let b:quitting_bang = 1 <bar> q!
endfunction

function! s:goyo_leave()
    call s:unWrapIt()
    " Quit Vim if this is the only remaining buffer
    if b:quitting && len(filter(range(1, bufnr('$')), 'buflisted(v:val)')) == 1
      if b:quitting_bang
        qa!
      else
        qa
      endif
    endif
endfunction

autocmd User GoyoEnter nested call <SID>goyo_enter()
autocmd User GoyoLeave nested call <SID>goyo_leave()

command! -nargs=* WrapIt :call s:wrapIt()
command! -nargs=* UnWrapIt :call s:unWrapIt()


" ---------- Trailing Whitespace Stripping ----------
function! <SID>StripTrailingWhitespace()
    " Preparation: save last search, and cursor position.
    let _s=@/
    let l = line(".")
    let c = col(".")
    " Do the business:
    %s/\s\+$//e
    " Clean up: restore previous search history, and cursor position
    let @/=_s
    call cursor(l, c)
endfunction
nmap <silent> <Leader>w :call <SID>StripTrailingWhitespace()<CR>

