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

The default `host` profile installs `smolvm` but no LLM agents. Machines
created by `devvm` contain `/etc/devvm-agent`, so the same bootstrap
automatically uses the `agent-vm` profile and installs Codex and Claude Code
there.

## Dev machines (`devvm`)

`devvm` is one frontend for persistent dev boxes across backends:

- **`smol`** — local, isolated [smolvm](https://smolmachines.com) microVMs.
- **`ssh`** — an existing SSH host (this subsumes the old `devtunnel`, which is
  now a thin shim over `devvm … scottdev3`).
- a cloud (`hetzner`) backend is stubbed for later; the ssh backend already
  carries the provisioning, auth, key-management, and hardening it will reuse.

```bash
devvm create client-a              # local smol VM
devvm create client-b --memory 4096
devvm auth client-a                # log in to github, codex, and claude
devvm shell client-a
devvm status                       # list every machine + state

# ssh machines
devvm exec scottdev3 hostname
devvm tunnel scottdev3             # autossh port forwards (up/down/status)
devvm mosh scottdev3              # roaming shell, attached to the dev tmux session
devvm vnc scottdev3
devvm authorize-key scottdev3       # prompt for a GitHub user and key labels
devvm keys scottdev3
devvm revoke-key scottdev3 laptop   # unique fingerprint/comment substring
devvm cleanup-keys scottdev3        # remove duplicates and the machine's own keys
devvm lockdown scottdev3           # firewall + sshd hardening (opt-in)
```

Per-machine config lives in `~/.config/devvm/machines/<name>.conf` (sourced
bash; hand-editable). `create` writes one automatically; ssh hosts are added by
dropping in a conf with `BACKEND=ssh` and `SSH_HOST=`. Repositories live only on
the machine's disk; no host directories or SSH agent are mounted.

For ssh/cloud machines, `authorized_keys` is seeded at bootstrap from
`AUTHORIZED_KEYS_GITHUB` (GitHub `.keys`) / `AUTHORIZED_KEYS`, and managed later
with `authorize-key` / `keys` / `revoke-key` / `cleanup-keys` — the model for reaching one box
from many client hosts. Managed hosts use an isolated `known_hosts`
(`accept-new` TOFU). `lockdown` (opt-in via `HARDEN=1` or the verb) sets a
default-deny firewall (SSH-only; dev ports stay tunnel-reachable), disables
password/root SSH login, and enables unattended security upgrades — fail-safe
(`sshd -t` + reload, and it refuses to run without a working key in place).

Authentication happens inside each machine. Because it has no browser,
`devvm auth` points `$BROWSER` at a shim that streams login URLs back to the
host, where they open in the host's default browser; tools that ignore
`$BROWSER` simply print the URL in the terminal as before. `devvm auth NAME`
with no tool logs in to all of github, codex, and claude in turn. Since the
outbox is a machine→host channel, the watcher only opens plain `http(s)` URLs
(no `file://`, custom schemes, or option injection). codex uses device auth when
the installed CLI supports it. Older codex versions complete OAuth on a
`127.0.0.1:1455` callback inside the machine, so only that fallback routes the
host's `:1455` back in — a smol port mapping (one-time restart) or, for ssh, a
transient `-L` on the login connection.
Creation prompts for memory with a host-aware default capped at 2 GiB; pass
`--memory MiB` to skip the prompt. `devvm shell` attaches to a persistent tmux
session. Subcommands, machine names, and auth tools tab-complete in fish.

`devvm create` and `devvm bootstrap` copy the current host dotfiles checkout
into the VM as an archive, including uncommitted changes. Host repository
metadata and all other root-level hidden files/directories are excluded. After
provisioning, the snapshot is attached to the host checkout's GitHub origin as
a colocated Jujutsu/Git repository; use `jj git fetch` and `jj git push`.
Host-only or unpublished changes remain visible as VM working-copy changes.

### How it's organized

- **`Brewfile`** / **`Brewfile.macos`** — declarative Homebrew package lists
  (formulae, casks, fonts), applied idempotently with `brew bundle`.
- **`Brewfile.agent`** — Codex and Claude Code casks installed only in agent VMs.
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
