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
- Installing Homebrew and packages (via `brew bundle`)
- Symlinking configs with GNU Stow
- Setting up tmux (TPM) and Neovim (lazy.nvim) plugins
- Setting fish as the default shell
- Installing GUI apps (if applicable)

Each step is interactive—you can skip anything you don't need. Run
`ASSUME_YES=1 bash bootstrap.sh` to accept every step non-interactively.

### How it's organized

- **`Brewfile`** / **`Brewfile.macos`** — declarative Homebrew package lists
  (formulae, casks, fonts), applied idempotently with `brew bundle`.
- **`packages.sh`** — single source of truth for stow packages plus the
  system packages Homebrew doesn't handle (Linux apt/flatpak). Sourced by
  both `bootstrap.sh` and `restow.sh`.
- **`bootstrap.sh`** — thin orchestrator that installs Homebrew, runs
  `brew bundle`, stows configs, and handles the remaining OS-specific bits.

## Manual Setup

If you prefer to set things up manually:

```bash
# Clone the repo
git clone git@github.com:smweber/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Install packages (includes GNU Stow 2.4+)
brew bundle --file Brewfile
brew bundle --file Brewfile.macos   # macOS only

# Stow the configs you want (use --no-folding to create individual symlinks)
stow --dotfiles --no-folding sh
stow --dotfiles --no-folding fish
stow --dotfiles --no-folding tmux
stow --dotfiles --no-folding nvim
stow --dotfiles --no-folding git
stow --dotfiles --no-folding jj
stow --dotfiles --no-folding alacritty  # GUI only
# Linux GUI: stow --dotfiles --no-folding i3 rofi polybar niri waybar
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
| niri       | Scrolling window manager | Linux GUI       |
| rofi       | App launcher             | Linux GUI       |
| polybar    | Status bar               | Linux GUI       |
| waybar     | Wayland status bar       | Linux GUI       |
| aerospace  | Window manager           | macOS           |

## Dependencies

Homebrew packages are declared in `Brewfile` (cross-platform) and
`Brewfile.macos` (macOS casks/fonts). System packages Homebrew doesn't
cover live in `packages.sh`:

- Linux GUI (apt): i3-wm, rofi, feh, polybar, brightnessctl, waybar, fuzzel, swaybg, swaylock, swayidle, wl-clipboard, playerctl
- Linux GUI apps (flatpak): Obsidian, Discord, Slack, Cryptomator

To change what gets installed, edit the `Brewfile`s or `packages.sh`—no
need to touch `bootstrap.sh`.

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
