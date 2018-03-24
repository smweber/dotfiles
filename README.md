Scott's Dotfiles
================

To use, first install GNU Stow.

Then:
 - `git clone git@github.com:smweber/dotfiles.git ~/.dotfiles`
 - `cd ~/.dotfiles`
 - `stow --no-folding sh`
 - `stow --no-folding nvim`
 - etc...

For Neovim:
 - Requires recent Neovim: https://github.com/neovim/neovim/wiki/Installing-Neovim
 - with vim-plug: https://github.com/junegunn/vim-plug
 - Then open nvim and type `:PlugInstall`

For tmux:
 - tmux can be `sudo apt install tmux`ed
 - needs Tmux Plugin Manager: https://github.com/tmux-plugins/tpm
 - Then a `Ctrl-a` + `I` should do it
