" ---------- Scott's Preferences ----------
nmap <Leader>nn :set invnumber<CR>
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

set mouse=a " turns out, even in the terminal, vim is just as sweet with a mouse

" -------- Specific filetype settings ---------
autocmd FileType html setlocal shiftwidth=2 softtabstop=2
autocmd FileType javascript setlocal shiftwidth=2 softtabstop=2
autocmd FileType typescript setlocal shiftwidth=2 softtabstop=2
autocmd FileType javascriptreact setlocal shiftwidth=2 softtabstop=2
autocmd FileType typescriptreact setlocal shiftwidth=2 softtabstop=2

" Colourscheme
"set termguicolors
colorscheme catppuccin
set background=dark
let g:airline_theme='catppuccin'

" Tab and window movement
nnoremap <c-k> <c-w><c-k>
nnoremap <c-j> <c-w><c-j>
nnoremap <c-h> <c-w><c-h>
nnoremap <c-l> <c-w><c-l>

" Yank and copy with system clipboard
set clipboard+=unnamedplus

" Easily reload config
command! ReloadConfig source $MYVIMRC | runtime! plugin/**/*.vim

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

