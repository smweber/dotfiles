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
 - with vim-plug: https://github.com/junegunn/vim-plug (auto installs)
 - Probably need some sweet py3 action: `pip3 install --user --upgrade neovim`
 - Then open nvim and type `:PlugInstall`
 - CoC will need `brew install node`

For tmux:
 - install tmux (`brew` or `apt` will do)
 - needs Tmux Plugin Manager: https://github.com/tmux-plugins/tpm
 - Then a `Ctrl-a` + `I` should do it

For fish:
 - install fish (`brew` or `apt` will do)
 - Also want patched fonts, perhaps from https://github.com/ryanoasis/nerd-fonts
    - `brew tap homebrew/cask-fonts`
    - `brew install font-meslo-lg-nerd-font`


Linux packages:
- i3, rofi, feh, polybar
