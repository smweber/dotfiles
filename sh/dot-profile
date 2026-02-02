# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

set -o vi

export EDITOR=nvim
export XDG_CONFIG_HOME=$HOME/.config

export GOPATH=$HOME/src/go
export GOTOOLCHAIN=local

export PATH="/opt/homebrew/bin:$PATH"
export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
export PATH="$GOPATH/bin:$PATH:"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.dotfiles/bin:$PATH"

export LIBRARY_PATH="/opt/homebrew/lib:/home/linuxbrew/.linuxbrew/lib:$LIBRARY_PATH"
export C_INCLUDE_PATH="/opt/homebrew/include:/home/linuxbrew/.linuxbrew/include:$C_INCLUDE_PATH"

# NOTE: Lines below are ignored by fish (it only parses "export" lines via
# parse_export_file in config.fish). These are bash-only, so we guard them.

# Cargo/Rust environment (if installed)
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Brew shellenv sets HOMEBREW_PREFIX and other vars (PATH already set above for fish)
[ -d "/home/linuxbrew/.linuxbrew" ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
[ -d "/opt/homebrew" ] && eval "$(/opt/homebrew/bin/brew shellenv)"

# Check to see if a file called .local_profile exists, and if it does source it
if [ -f "$HOME/.local_profile" ]; then
  . "$HOME/.local_profile"
fi
