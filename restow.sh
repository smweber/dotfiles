#!/bin/bash
#
# Restow script - safely refresh symlinks after pulling dotfiles changes
# Run this after: git pull (or jj git fetch)
#
# Usage: ./restow.sh [packages...]
#        ./restow.sh           # restow all packages
#        ./restow.sh fish nvim # restow specific packages
#

set -e

cd ~/.dotfiles

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==>${NC} $1"; }
error() { echo -e "${RED}==>${NC} $1"; }

# Check for stow 2.4+ (required for --dotfiles --no-folding to work together)
check_stow() {
    if ! command -v stow &> /dev/null; then
        return 1
    fi
    local version=$(stow --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local major=$(echo "$version" | cut -d. -f1)
    local minor=$(echo "$version" | cut -d. -f2)
    [[ "$major" -gt 2 ]] || [[ "$major" -eq 2 && "$minor" -ge 4 ]]
}

# Install stow from homebrew
install_stow() {
    if ! command -v brew &> /dev/null; then
        error "Homebrew is required to install stow 2.4+"
        error "Install homebrew first: https://brew.sh"
        exit 1
    fi
    info "Installing GNU Stow from Homebrew..."
    brew install stow
}

# Main
info "Checking GNU Stow version..."
if check_stow; then
    info "GNU Stow $(stow --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) OK"
else
    warn "GNU Stow 2.4+ required (apt version is too old)"
    install_stow
fi

# Determine packages to stow
if [[ $# -gt 0 ]]; then
    PACKAGES="$@"
else
    # All stow packages (directories with dot- prefixed contents)
    PACKAGES="sh fish tmux nvim git jj alacritty"
    # Add platform-specific
    if [[ "$OSTYPE" == "darwin"* ]]; then
        PACKAGES="$PACKAGES aerospace"
    elif [[ -n "$DISPLAY" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
        PACKAGES="$PACKAGES i3 rofi polybar"
    fi
fi

info "Packages to stow: $PACKAGES"

# Find and show broken symlinks pointing to dotfiles
info "Checking for broken symlinks..."
BROKEN=$(find ~ ~/.config -maxdepth 3 -type l -lname '*/.dotfiles/*' ! -exec test -e {} \; -print 2>/dev/null || true)

if [[ -n "$BROKEN" ]]; then
    warn "Found broken symlinks pointing to dotfiles:"
    echo "$BROKEN" | head -20
    COUNT=$(echo "$BROKEN" | wc -l)
    if [[ $COUNT -gt 20 ]]; then
        echo "  ... and $((COUNT - 20)) more"
    fi
    echo ""
    read -p "Remove these broken symlinks? [Y/n] " -n 1 -r < /dev/tty
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "$BROKEN" | xargs rm -f
        info "Removed $COUNT broken symlinks"
    fi
fi

# Stow each package
info "Stowing packages..."
for pkg in $PACKAGES; do
    if [[ -d "$pkg" ]]; then
        echo -n "  $pkg... "
        if stow --dotfiles --no-folding "$pkg" 2>/dev/null; then
            echo "OK"
        else
            # Try to identify conflict
            OUTPUT=$(stow --dotfiles --no-folding "$pkg" 2>&1 || true)
            if echo "$OUTPUT" | grep -q "existing target"; then
                echo "CONFLICT (file exists)"
                echo "$OUTPUT" | grep "existing target" | head -2 | sed 's/^/    /'
            else
                echo "FAILED"
                echo "$OUTPUT" | head -2 | sed 's/^/    /'
            fi
        fi
    else
        echo "  $pkg... SKIP (not found)"
    fi
done

info "Done!"
