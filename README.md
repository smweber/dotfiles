# Scott's Dotfiles

Config files for macOS and Linux (Debian-based). Works on GUI systems or headless servers.

## Quick Start

Run the bootstrap script on a fresh machine:

```bash
curl -fsSL https://raw.githubusercontent.com/smweber/dotfiles/master/bootstrap.sh | bash
```

The script will guide you through:
- Updating system packages (Linux)
- Setting up SSH keys and GitHub access
- Cloning this repo to `~/.dotfiles`
- Installing and running GNU Stow
- Installing Homebrew and packages
- Setting up tmux with TPM
- Installing GUI apps (if applicable)

Each step is interactive—you can skip anything you don't need.

## Manual Setup

If you prefer to set things up manually:

```bash
# Clone the repo
git clone git@github.com:smweber/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Install stow
# macOS: brew install stow
# Linux: sudo apt install stow

# Stow the configs you want (use --no-folding to create individual symlinks)
stow --no-folding sh
stow --no-folding fish
stow --no-folding tmux
stow --no-folding nvim
stow --no-folding git
stow --no-folding jj
stow --no-folding alacritty  # GUI only
# Linux GUI: stow --no-folding i3 rofi polybar
# macOS: stow --no-folding aerospace
```

## What's Included

| Package    | Description              | Platform        |
|------------|--------------------------|-----------------|
| sh         | Shell profile, aliases   | All             |
| fish       | Fish shell config        | All             |
| tmux       | Tmux config with TPM     | All             |
| nvim       | Neovim config            | All             |
| git        | Git config               | All             |
| jj         | Jujutsu config           | All             |
| alacritty  | Terminal emulator        | GUI             |
| i3         | Window manager           | Linux GUI       |
| rofi       | App launcher             | Linux GUI       |
| polybar    | Status bar               | Linux GUI       |
| aerospace  | Window manager           | macOS           |

## Dependencies

Installed by the bootstrap script:
- fish, tmux, neovim, mise, jj, fzf, ripgrep, bat
- btop, direnv, tree
- font-meslo-lg-nerd-font

Linux GUI: i3-wm, rofi, feh, polybar, brightnessctl
