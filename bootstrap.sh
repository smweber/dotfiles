#!/bin/bash
#
# Bootstrap script for fresh computer installs
# https://github.com/smweber/dotfiles
#
# Run with: curl -fsSL https://raw.githubusercontent.com/smweber/dotfiles/master/bootstrap.sh | bash
#
# Package lists live in Brewfile / Brewfile.macos (brew) and packages.sh
# (stow / apt / flatpak). This script just orchestrates.
#
# Non-interactive run: ASSUME_YES=1 bash bootstrap.sh
#

set -uo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"

# ============================================================================
# Helper Functions
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Steps that failed are collected here and reported at the end instead of
# aborting the whole run.
FAILED=()

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    else
        echo -e "${RED}Unsupported OS: $OSTYPE${NC}"
        exit 1
    fi
}

# Detect if Linux has a GUI
has_gui() {
    if [[ "$OS" == "macos" ]]; then
        return 0
    fi
    if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        return 0
    fi
    return 1
}

step() { echo ""; echo -e "${BLUE}==>${NC} ${GREEN}$1${NC}"; }
info() { echo -e "    $1"; }
warn() { echo -e "    ${YELLOW}$1${NC}"; }

# Ask user yes/no, default yes. Honors ASSUME_YES=1 for unattended runs.
# Reads from /dev/tty so it works when piped from curl.
ask() {
    echo ""
    echo -e "${YELLOW}$1${NC}"
    if [[ "${ASSUME_YES:-0}" == "1" ]]; then
        echo "[Y/n] y (auto)"
        return 0
    fi
    read -p "[Y/n] " -n 1 -r < /dev/tty
    echo
    [[ $REPLY =~ ^[Nn]$ ]] && return 1
    return 0
}

# Run a command, echoing it first. Records (but does not abort on) failures.
run() {
    echo -e "    ${BLUE}\$${NC} $*"
    if ! eval "$*"; then
        warn "command failed: $*"
        FAILED+=("$*")
        return 1
    fi
}

# Check if command exists
has() { command -v "$1" &> /dev/null; }

# Make brew available in this shell session (after install or if preinstalled)
load_brew() {
    if has brew; then return 0; fi
    if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    has brew
}

# ============================================================================
# Main Script
# ============================================================================

main() {
    detect_os

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Dotfiles Bootstrap Script                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Detected OS: ${BLUE}$OS${NC}"
    if has_gui; then
        echo -e "GUI detected: ${BLUE}yes${NC}"
        HAS_GUI=true
    else
        echo -e "GUI detected: ${BLUE}no (headless)${NC}"
        HAS_GUI=false
    fi

    # -------------------------------------------------------------------------
    # Update package manager (Linux only)
    # -------------------------------------------------------------------------
    if [[ "$OS" == "linux" ]] && has apt; then
        step "Update system packages"
        if ask "Update and upgrade system packages (apt)?"; then
            run "sudo apt update"
            run "sudo apt upgrade -y"
        fi
    fi

    # -------------------------------------------------------------------------
    # Generate SSH key
    # -------------------------------------------------------------------------
    step "SSH Key Setup"
    if [[ -f ~/.ssh/id_ed25519 ]]; then
        info "SSH key already exists at ~/.ssh/id_ed25519"
    else
        info "No SSH key found at ~/.ssh/id_ed25519"
        if ask "Generate a new SSH key?"; then
            read -p "Enter your email for the SSH key: " email < /dev/tty
            run "ssh-keygen -t ed25519 -C \"$email\""
        fi
    fi

    # -------------------------------------------------------------------------
    # Clone dotfiles repo
    # -------------------------------------------------------------------------
    step "Clone dotfiles repository"
    if [[ -d "$DOTFILES" ]]; then
        info "Dotfiles already exist at $DOTFILES, skipping"
    else
        info "This will clone smweber/dotfiles to $DOTFILES"
        if ask "Clone dotfiles repository?"; then
            run "git clone https://github.com/smweber/dotfiles.git \"$DOTFILES\""
        fi
    fi

    # Load shared package config now that the repo should exist.
    if [[ -f "$DOTFILES/packages.sh" ]]; then
        # shellcheck source=packages.sh
        source "$DOTFILES/packages.sh"
    else
        warn "packages.sh not found at $DOTFILES - clone the repo first. Aborting."
        exit 1
    fi

    # -------------------------------------------------------------------------
    # Install Homebrew (provides stow + cross-platform packages via Brewfile)
    # -------------------------------------------------------------------------
    step "Install Homebrew"
    if load_brew; then
        info "Homebrew is already installed"
    else
        info "Homebrew provides GNU Stow (apt's is too old) and the Brewfile packages"
        if ask "Install Homebrew?"; then
            run '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
            load_brew
        fi
    fi

    # -------------------------------------------------------------------------
    # Install packages via Brewfile (idempotent)
    # -------------------------------------------------------------------------
    if has brew; then
        step "Install packages via Homebrew (brew bundle)"
        info "Common packages: $DOTFILES/Brewfile"
        [[ "$OS" == "macos" ]] && info "macOS packages/casks: $DOTFILES/Brewfile.macos"
        if ask "Run brew bundle?"; then
            run "brew bundle --file \"$DOTFILES/Brewfile\""
            if [[ "$OS" == "macos" ]]; then
                run "brew bundle --file \"$DOTFILES/Brewfile.macos\""
            fi
        fi
    else
        warn "Homebrew not available - skipping brew packages and stow install"
    fi

    # -------------------------------------------------------------------------
    # Add SSH key to GitHub, then use SSH for the dotfiles remote
    # -------------------------------------------------------------------------
    step "Add SSH key to GitHub"
    GITHUB_SSH_READY=false
    if [[ -f ~/.ssh/id_ed25519.pub ]]; then
        if has gh; then
            if ask "Upload SSH key to GitHub via gh?"; then
                if gh auth status &>/dev/null || run "gh auth login"; then
                    LOCAL_SSH_KEY="$(awk '{print $1 " " $2}' ~/.ssh/id_ed25519.pub)"
                    if gh api user/keys --paginate --jq '.[].key' 2>/dev/null |
                        awk '{print $1 " " $2}' |
                        grep -Fqx "$LOCAL_SSH_KEY"; then
                        info "SSH key is already registered with GitHub"
                        GITHUB_SSH_READY=true
                    else
                        if run "gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$(hostname)\""; then
                            GITHUB_SSH_READY=true
                        fi
                    fi
                fi
            fi
        else
            info "GitHub CLI not available; add this public key manually:"
            echo ""
            cat ~/.ssh/id_ed25519.pub
            echo ""
            info "https://github.com/settings/keys"
        fi
    else
        info "No SSH public key found, skipping"
    fi

    if [[ "$GITHUB_SSH_READY" == "true" ]] &&
        [[ -d "$DOTFILES/.git" ]] &&
        git -C "$DOTFILES" remote get-url origin &>/dev/null; then
        run "git -C \"$DOTFILES\" remote set-url origin git@github.com:smweber/dotfiles.git"
    fi

    # -------------------------------------------------------------------------
    # Stow dotfiles
    # -------------------------------------------------------------------------
    step "Stow dotfiles"
    if has stow; then
        ALL_STOW="$(stow_packages "$OS" "$HAS_GUI")"
        info "This symlinks config files to your home directory"
        info "Packages to stow: $ALL_STOW"
        if ask "Stow these packages?"; then
            cd "$DOTFILES" || exit 1
            for pkg in $ALL_STOW; do
                if [[ -d "$pkg" ]]; then
                    info "Stowing $pkg..."
                    if STOW_OUTPUT="$(stow --dotfiles --no-folding "$pkg" 2>&1)"; then
                        [[ -n "$STOW_OUTPUT" ]] && info "$STOW_OUTPUT"
                    else
                        warn "$pkg: stow failed"
                        while IFS= read -r line; do
                            warn "  $line"
                        done <<< "$STOW_OUTPUT"
                        FAILED+=("stow --dotfiles --no-folding $pkg")
                    fi
                fi
            done
        fi
    else
        warn "stow not installed - skipping (install Homebrew + brew bundle first)"
    fi

    # -------------------------------------------------------------------------
    # tmux: TPM + plugins + theme pin
    # -------------------------------------------------------------------------
    step "Install TPM (Tmux Plugin Manager)"
    if [[ -d ~/.tmux/plugins/tpm ]]; then
        info "TPM is already installed"
    elif ask "Install TPM?"; then
        run "git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
    fi

    step "Install tmux plugins"
    if [[ -f ~/.tmux/plugins/tpm/bin/install_plugins ]]; then
        if ask "Install tmux plugins?"; then
            run "~/.tmux/plugins/tpm/bin/install_plugins"
        fi
    else
        info "TPM not found, skipping"
    fi

    # (catppuccin theme is pinned to v0.3.0 in tmux/dot-tmux.conf, so no
    # post-install checkout hack is needed anymore.)

    # -------------------------------------------------------------------------
    # Sync Neovim plugins (lazy.nvim) headlessly
    # -------------------------------------------------------------------------
    step "Sync Neovim plugins"
    if has nvim; then
        if ask "Install/sync Neovim plugins headlessly?"; then
            run "nvim --headless '+Lazy! sync' +qa"
        fi
    else
        info "nvim not found, skipping"
    fi

    # -------------------------------------------------------------------------
    # Set fish as the default login shell
    # -------------------------------------------------------------------------
    step "Set fish as default shell"
    FISH_PATH="$(command -v fish || true)"
    if [[ -z "$FISH_PATH" ]]; then
        info "fish not found, skipping"
    elif [[ "${SHELL:-}" == "$FISH_PATH" ]]; then
        info "fish is already the default shell"
    elif ask "Set fish as your default login shell?"; then
        grep -qx "$FISH_PATH" /etc/shells 2>/dev/null || \
            run "echo '$FISH_PATH' | sudo tee -a /etc/shells >/dev/null"
        run "chsh -s '$FISH_PATH'"
    fi

    # -------------------------------------------------------------------------
    # Linux GUI packages (apt) - not covered by Homebrew
    # -------------------------------------------------------------------------
    if [[ "$OS" == "linux" ]] && [[ "$HAS_GUI" == "true" ]] && has apt; then
        step "Install Linux GUI packages (apt)"
        info "Packages: $LINUX_GUI_APT"
        info "Nerd font: install manually on Linux (font-meslo-lg-nerd-font is a macOS cask)"
        if ask "Install Linux GUI packages?"; then
            run "sudo apt install -y $LINUX_GUI_APT"
        fi
    fi

    # -------------------------------------------------------------------------
    # Install Claude Code
    # -------------------------------------------------------------------------
    step "Install Claude Code"
    if has claude; then
        info "Claude Code is already installed"
    elif ask "Install Claude Code?"; then
        run 'curl -fsSL https://claude.ai/install.sh | bash'
    fi

    # -------------------------------------------------------------------------
    # Configure Claude Code statusline
    # -------------------------------------------------------------------------
    step "Configure Claude Code statusline"
    CLAUDE_SETTINGS="$HOME/.claude/settings.json"
    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        if python3 -c "import json; d=json.load(open('$CLAUDE_SETTINGS')); exit(0 if 'statusLine' in d else 1)" 2>/dev/null; then
            info "statusLine already configured in $CLAUDE_SETTINGS"
        else
            info "Adding statusLine config to $CLAUDE_SETTINGS"
            python3 - "$CLAUDE_SETTINGS" <<'EOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)
d["statusLine"] = {"type": "command", "command": "~/.dotfiles/bin/claude-statusline-command.sh"}
with open(path, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
EOF
        fi
    else
        info "~/.claude/settings.json not found - run after Claude Code is installed"
    fi

    # -------------------------------------------------------------------------
    # Linux GUI software (flatpak)
    # -------------------------------------------------------------------------
    if [[ "$OS" == "linux" ]] && [[ "$HAS_GUI" == "true" ]]; then
        step "Install Linux GUI applications (flatpak)"
        info "Apps: $LINUX_FLATPAK"
        if has flatpak; then
            if ask "Install these apps via Flatpak?"; then
                run "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
                for app in $LINUX_FLATPAK; do
                    run "flatpak install -y flathub $app"
                done
            fi
        else
            info "Flatpak not found. Install it with: sudo apt install flatpak"
        fi

        echo ""
        warn "Remember to install these manually:"
        info "  - $LINUX_MANUAL"
    fi

    # -------------------------------------------------------------------------
    # macOS manual apps (not available via cask / needs App Store)
    # -------------------------------------------------------------------------
    if [[ "$OS" == "macos" ]] && [[ -n "$MACOS_MANUAL" ]]; then
        echo ""
        warn "Remember to install these manually (App Store / direct download):"
        for app in $MACOS_MANUAL; do
            info "  - $app"
        done
    fi

    # -------------------------------------------------------------------------
    # Done!
    # -------------------------------------------------------------------------
    if [[ ${#FAILED[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Bootstrap completed with failures.${NC}"
        echo ""
        warn "${#FAILED[@]} step(s) failed - review and re-run as needed:"
        for c in "${FAILED[@]}"; do
            echo -e "      ${RED}✗${NC} $c"
        done
        echo ""
    else
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║           Bootstrap Complete!                              ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
    fi

    info "Next steps:"
    info "  - Restart your terminal (or run: source ~/.profile)"
    echo ""

    [[ ${#FAILED[@]} -eq 0 ]]
}

main "$@"
