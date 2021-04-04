#!/bin/bash

### Configure which packages to install and configurations to unstow ###
COMMON_PKGS=(
    fish
    tmux
    neovim
    git
    node
    mosh
    direnv
)
COMMON_STOWS=(
    sh
    nvim
    tmux
    fish
    git
)

SPIN_PKGS=()
SPIN_STOWS=()

BREW_CASKS=(
    homebrew/cask-fonts
)
BREW_PKGS=(
    ranger
    font-meslo-lg-nerd-font
)
BREW_STOWS=(
    ranger
    alacritty
)

NIX_PKGS=(
    ranger
    font-meslo-lg-nerd-font
)
NIX_STOWS=(
    ranger
    alacritty
)


### Create lists of packages/configurations and build commands to run ###

if [[ $SPIN ]]; then
    PKGS=("${COMMON_PKGS[@]}" "${SPIN_PKGS[@]}")
    STOWS=("${COMMON_STOW[@]}" "${SPIN_STOW[@]}")
    function installcmd () {
        sudo apt-get install -y $1
    }
elif [[ $1 == "brew" ]]; then
    PKGS=("${COMMON_PKGS[@]}" "${BREW_PKGS[@]}")
    STOWS=("${COMMON_STOWS[@]}" "${BREW_STOWS[@]}")
    function installcmd () {
        (brew ls --version $1 && echo "$1 already installed") || (echo "Installing $1" && brew install $1)
    }
    # Need to install casks for homebrew
    for CASK in ${BREW_CASKS[@]}; do
        (brew tap | grep $CASK && echo "$CASK already tapped") || brew tap $CASK
    done
elif [[ $1 == "nix" ]]; then
    PKGS=("${COMMON_PKGS[@]}" "${NIX_PKGS[@]}")
    STOWS=("${COMMON_STOWS[@]}" "${NIX_STOWS[@]}")
    function installcmd () {
        nix-env -i $1
    }
else
    echo "Please specify \"brew\" or \"nix\""
    echo "(add \"dry\" after for a dry run)"
    exit 1
fi

if [[ $2 = "dry" ]]; then
    function installcmd () {
        echo Would install $1
    }
    function stowcmd () {
        echo Would unstow $1
    }
else
    function stowcmd () {
        stow --no-folding $1
    }
fi


### Install packages and link configurations ###

for PKG in ${PKGS[@]}; do
    installcmd $PKG
done

for STOW in ${STOWS[@]}; do
    stowcmd $STOW
done

if [[ $2 = "dry" ]]; then
    exit 0
fi


# Install TPM if not already installed
if [[ ! -d ~/.tmux/plugins/tpm ]]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
    echo "TPM already installed"
fi
