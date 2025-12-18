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
Plug 'christoomey/vim-tmux-navigator'
Plug 'scrooloose/nerdtree'
Plug 'chrisbra/Colorizer'
"Plug 'airblade/vim-gitgutter'

Plug 'algmyr/vclib.nvim'
Plug 'algmyr/vcsigns.nvim' " VCS agnostic gutter signs

" Themes
Plug 'catppuccin/nvim', { 'as': 'catppuccin' }
Plug 'joshdick/onedark.vim'
Plug 'rakr/vim-one'

" Development
Plug 'junegunn/fzf'         " File opening and more (basic fzf wrapper)
Plug 'junegunn/fzf.vim'     " (Need this one too for nice functionality)
Plug 'sheerun/vim-polyglot' " A collection of language packs
Plug 'tpope/vim-sleuth'     " Heuristically set buffer options
Plug 'APZelos/blamer.nvim'

" Specifically to get :Gbrowse
"Plug 'tpope/vim-fugitive'
"Plug 'tpope/vim-rhubarb'

" CoC (LSP support for 'intellisense') - MIGRATING TO NATIVE LSP
" Plug 'neoclide/coc.nvim', {'branch': 'release'}
" Plug 'liuchengxu/vista.vim'

" Native LSP & Completion
Plug 'neovim/nvim-lspconfig'
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'L3MON4D3/LuaSnip'
Plug 'saadparwaiz1/cmp_luasnip'

" Symbol outline & fuzzy finder
Plug 'stevearc/aerial.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-lua/plenary.nvim'

" Treesitter
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
" Note: nvim-treesitter-textobjects is incompatible with latest nvim-treesitter
" Plug 'nvim-treesitter/nvim-treesitter-textobjects'

" Autoformatting (for Go)
Plug 'sbdchd/neoformat'

" Writing
Plug 'junegunn/goyo.vim'

" AI
"Plug 'github/copilot.vim'
Plug 'Exafunction/windsurf.vim'

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
"function! NearestMethodOrFunction() abort
"  return get(b:, 'vista_nearest_method_or_function', '')
"endfunction
"set statusline+=%{NearestMethodOrFunction()}

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

" Fix airline/neovim whitespace trailing bug
" (https://github.com/vim-airline/vim-airline/issues/2704)
let g:airline#extensions#whitespace#symbol = '!'

" VCSigns config and keybindings
lua << EOF
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
EOF

" (Note: CoC config is separate, in coc-config.vim)
