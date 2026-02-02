#!/bin/bash
#
# Bootstrap script for fresh computer installs
# https://github.com/smweber/dotfiles
#
# Run with: curl -fsSL https://raw.githubusercontent.com/smweber/dotfiles/master/bootstrap.sh | bash
#

set -e

# ============================================================================
# Package Configuration - Edit these to customize what gets installed
# ============================================================================

# Stow packages (subdirectories in ~/.dotfiles)
STOW_COMMON="sh tmux fish git jj nvim"
STOW_MACOS="alacritty aerospace"
STOW_LINUX_GUI="alacritty i3 rofi polybar"

# Homebrew packages (installed on both macOS and Linux)
BREW_PACKAGES="fish tmux neovim mise jj fzf ripgrep bat"
BREW_FONTS="font-meslo-lg-nerd-font"

# Extra packages (brew on macOS, apt on Linux)
EXTRA_PACKAGES="btop direnv tree"

# Linux GUI packages (apt)
LINUX_GUI_APT="i3-wm rofi feh polybar brightnessctl alacritty"

# macOS GUI apps (brew casks)
MACOS_CASKS="alacritty cryptomator obsidian discord slack firefox"
MACOS_CASKS_EXTRA="nikitabobko/tap/aerospace"

# macOS apps to install manually
MACOS_MANUAL="Choosy DaisyDisk Maccy Yoink 1Password Things Steam"

# Linux GUI apps (flatpak)
LINUX_FLATPAK="md.obsidian.Obsidian com.discordapp.Discord com.slack.Slack org.cryptomator.Cryptomator"

# Linux apps to install manually
LINUX_MANUAL="1Password (https://1password.com/downloads/linux/)"

# ============================================================================
# Helper Functions
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    # Check for display server
    if [[ -n "$DISPLAY" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
        return 0
    fi
    return 1
}

# Print step header
step() {
    echo ""
    echo -e "${BLUE}==>${NC} ${GREEN}$1${NC}"
}

# Print info
info() {
    echo -e "    $1"
}

# Ask user yes/no, default yes
# Note: reads from /dev/tty so it works when script is piped from curl
ask() {
    echo ""
    echo -e "${YELLOW}$1${NC}"
    read -p "[Y/n] " -n 1 -r < /dev/tty
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        return 1
    fi
    return 0
}

# Run command with description
run() {
    echo -e "    ${BLUE}\$${NC} $1"
    eval "$1"
}

# Check if command exists
has() {
    command -v "$1" &> /dev/null
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
    if [[ "$OS" == "linux" ]]; then
        step "Update system packages"
        info "This will run: sudo apt update && sudo apt upgrade"
        if ask "Update and upgrade system packages?"; then
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
    # Add SSH key to GitHub
    # -------------------------------------------------------------------------
    step "Add SSH key to GitHub"
    if [[ -f ~/.ssh/id_ed25519.pub ]]; then
        info "Your public SSH key:"
        echo ""
        cat ~/.ssh/id_ed25519.pub
        echo ""
        info "Add this key to GitHub: https://github.com/settings/keys"
        if ask "Press Y when you've added the key to GitHub (or N to skip)"; then
            info "Testing GitHub connection..."
            ssh -T git@github.com 2>&1 || true
        fi
    else
        info "No SSH public key found, skipping"
    fi

    # -------------------------------------------------------------------------
    # Clone dotfiles repo
    # -------------------------------------------------------------------------
    step "Clone dotfiles repository"
    if [[ -d ~/.dotfiles ]]; then
        info "Dotfiles already exist at ~/.dotfiles, skipping"
    else
        info "This will clone smweber/dotfiles to ~/.dotfiles"
        if ask "Clone dotfiles repository?"; then
            run "git clone git@github.com:smweber/dotfiles.git ~/.dotfiles"
        fi
    fi

    # -------------------------------------------------------------------------
    # Install Homebrew (needed for stow and other packages)
    # -------------------------------------------------------------------------
    step "Install Homebrew"
    if has brew; then
        info "Homebrew is already installed"
    else
        info "Homebrew is required for GNU Stow (apt version is too old)"
        info "and will be used for other packages as well"
        if ask "Install Homebrew?"; then
            run '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
            # Add brew to path for this session
            if [[ "$OS" == "linux" ]]; then
                eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
            else
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
        fi
    fi

    # -------------------------------------------------------------------------
    # Install GNU Stow (from Homebrew - apt version is too old for --dotfiles)
    # -------------------------------------------------------------------------
    step "Install GNU Stow"
    if has stow && [[ "$(stow --version 2>&1)" == *"2.4"* ]]; then
        info "GNU Stow 2.4+ is already installed"
    else
        if has brew; then
            if ask "Install GNU Stow from Homebrew?"; then
                run "brew install stow"
            fi
        else
            info "Homebrew is required to install stow. Please install Homebrew first."
        fi
    fi

    # -------------------------------------------------------------------------
    # Stow dotfiles
    # -------------------------------------------------------------------------
    step "Stow dotfiles"
    info "This will symlink config files to your home directory"

    # Select platform-specific packages
    if [[ "$OS" == "macos" ]]; then
        STOW_PLATFORM="$STOW_MACOS"
    elif [[ "$HAS_GUI" == "true" ]]; then
        STOW_PLATFORM="$STOW_LINUX_GUI"
    else
        STOW_PLATFORM=""
    fi

    ALL_STOW="$STOW_COMMON $STOW_PLATFORM"
    info "Packages to stow: $ALL_STOW"

    if ask "Stow these packages?"; then
        cd ~/.dotfiles
        for pkg in $ALL_STOW; do
            if [[ -d "$pkg" ]]; then
                info "Stowing $pkg..."
                stow --dotfiles --no-folding "$pkg" 2>/dev/null || info "  (already stowed or conflict)"
            fi
        done
    fi

    # -------------------------------------------------------------------------
    # Install packages via Homebrew
    # -------------------------------------------------------------------------
    if has brew; then
        step "Install packages via Homebrew"
        info "Packages: $BREW_PACKAGES"
        info "Fonts: $BREW_FONTS"
        if ask "Install these packages via Homebrew?"; then
            run "brew install $BREW_PACKAGES"
            run "brew install --cask $BREW_FONTS" || run "brew install $BREW_FONTS"
        fi
    fi

    # -------------------------------------------------------------------------
    # Install additional packages
    # -------------------------------------------------------------------------
    step "Install additional packages"
    info "Packages: $EXTRA_PACKAGES"
    if ask "Install these packages?"; then
        if [[ "$OS" == "macos" ]]; then
            run "brew install $EXTRA_PACKAGES"
        else
            run "sudo apt install -y $EXTRA_PACKAGES"
        fi
    fi

    # -------------------------------------------------------------------------
    # Install TPM (Tmux Plugin Manager)
    # -------------------------------------------------------------------------
    step "Install TPM (Tmux Plugin Manager)"
    if [[ -d ~/.tmux/plugins/tpm ]]; then
        info "TPM is already installed"
    else
        if ask "Install TPM?"; then
            run "git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
        fi
    fi

    # -------------------------------------------------------------------------
    # Install tmux plugins
    # -------------------------------------------------------------------------
    step "Install tmux plugins"
    info "This will start tmux headless and install plugins"
    if ask "Install tmux plugins?"; then
        if [[ -f ~/.tmux/plugins/tpm/bin/install_plugins ]]; then
            run "~/.tmux/plugins/tpm/bin/install_plugins"
        else
            info "TPM not found, skipping"
        fi
    fi

    # -------------------------------------------------------------------------
    # TEMPORARY: Fix tmux theme
    # -------------------------------------------------------------------------
    step "Fix tmux theme (temporary)"
    info "Checking out specific commit for tmux theme compatibility"
    if [[ -d ~/.tmux/plugins/tmux ]]; then
        if ask "Checkout tmux theme commit 5ed4e8a6?"; then
            run "cd ~/.tmux/plugins/tmux && git checkout 5ed4e8a6"
        fi
    else
        info "Tmux theme plugin not found, skipping"
    fi

    # -------------------------------------------------------------------------
    # Linux GUI packages (apt)
    # -------------------------------------------------------------------------
    if [[ "$OS" == "linux" ]] && [[ "$HAS_GUI" == "true" ]]; then
        step "Install Linux GUI packages (apt)"
        info "Packages: $LINUX_GUI_APT"
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
    else
        if ask "Install Claude Code?"; then
            run 'curl -fsSL https://claude.ai/install.sh | bash'
        fi
    fi

    # -------------------------------------------------------------------------
    # macOS GUI software
    # -------------------------------------------------------------------------
    if [[ "$OS" == "macos" ]]; then
        step "Install macOS GUI applications"
        info "Apps: $MACOS_CASKS"
        info "Also: $MACOS_CASKS_EXTRA"
        if ask "Install these apps via Homebrew?"; then
            for app in $MACOS_CASKS; do
                run "brew install --cask $app" || info "  Failed to install $app"
            done
            for app in $MACOS_CASKS_EXTRA; do
                run "brew install --cask $app" || info "  Failed to install $app"
            done
        fi

        echo ""
        echo -e "    ${YELLOW}Remember to install these manually:${NC}"
        for app in $MACOS_MANUAL; do
            info "  - $app"
        done
    fi

    # -------------------------------------------------------------------------
    # Linux GUI software (flatpak)
    # -------------------------------------------------------------------------
    if [[ "$OS" == "linux" ]] && [[ "$HAS_GUI" == "true" ]]; then
        step "Install Linux GUI applications (flatpak)"
        info "Apps: $LINUX_FLATPAK"
        if has flatpak; then
            if ask "Install these apps via Flatpak?"; then
                for app in $LINUX_FLATPAK; do
                    run "flatpak install -y flathub $app" || info "  Failed to install $app"
                done
            fi
        else
            info "Flatpak not found. Install it with: sudo apt install flatpak"
        fi

        echo ""
        echo -e "    ${YELLOW}Remember to install these manually:${NC}"
        info "  - $LINUX_MANUAL"
    fi

    # -------------------------------------------------------------------------
    # Done!
    # -------------------------------------------------------------------------
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Bootstrap Complete!                              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    info "Next steps:"
    info "  - Restart your terminal (or run: source ~/.profile)"
    echo ""
}

main "$@"
