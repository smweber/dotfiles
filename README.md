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
stow --dotfiles --no-folding sh
stow --dotfiles --no-folding fish
stow --dotfiles --no-folding tmux
stow --dotfiles --no-folding nvim
stow --dotfiles --no-folding git
stow --dotfiles --no-folding jj
stow --dotfiles --no-folding alacritty  # GUI only
# Linux GUI: stow --dotfiles --no-folding i3 rofi polybar
# macOS: stow --dotfiles --no-folding aerospace
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

## Agent Workspace Artifacts

`bin/agent.sh` can seed build artifacts between JJ workspaces.

- Manifest path: `~/src/agent-workspaces/<repo>/agent-artifacts`
- Format: one repo-relative path per line (for example `build` or `target`)
- Behavior:
  - On first workspace create/switch in a repo, the manifest is auto-created with detected defaults.
  - When creating or switching to a workspace, missing listed paths are copied from the current workspace.
- Controls:
  - `agent artifacts disable` / `agent artifacts enable` (persistent per-repo opt-out/opt-in)
  - `agent artifacts clean [workspace]` (remove configured artifact paths from current or named workspace)
  - `AGENT_DISABLE_ARTIFACT_HYDRATION=1` (one-shot opt-out for a single command)
