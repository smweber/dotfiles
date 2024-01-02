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
export N_PREFIX=$HOME/.n
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
export PATH="$HOME/.n/bin:$PATH"
export PATH=$GOPATH/bin:$PATH
export PATH="$HOME/.beeper-stack-tools:$PATH"
export PATH="$HOME/.dotfiles/bin:$PATH"
export LIBRARY_PATH="/opt/homebrew/lib:/home/linuxbrew/.linuxbrew/lib:$LIBRARY_PATH"
export C_INCLUDE_PATH="/opt/homebrew/include:/home/linuxbrew/.linuxbrew/include:$C_INCLUDE_PATH"
. "$HOME/.cargo/env"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Check to see if a file called .local_profile exists, and if it does source it
if [ -f "$HOME/.local_profile" ]; then
  . "$HOME/.local_profile"
fi
