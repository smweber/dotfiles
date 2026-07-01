#!/bin/bash
#
# Shared package configuration - sourced by bootstrap.sh and restow.sh.
# This is the single source of truth for stow packages and OS-specific
# system packages. Homebrew packages live in the Brewfile(s) instead.
#

# ----------------------------------------------------------------------------
# Stow packages (subdirectories in ~/.dotfiles)
# ----------------------------------------------------------------------------
STOW_COMMON="sh tmux fish git jj nvim"
STOW_MACOS="alacritty aerospace paneru"
STOW_LINUX_GUI="alacritty i3 rofi polybar niri waybar"

# ----------------------------------------------------------------------------
# System packages that Homebrew does NOT handle (Linux GUI / desktop apps)
# ----------------------------------------------------------------------------
# Linux GUI packages (apt) - window managers, bars, wayland tooling
LINUX_GUI_APT="i3-wm rofi feh polybar brightnessctl alacritty waybar fuzzel swaybg swaylock swayidle wl-clipboard playerctl"

# Linux GUI apps (flatpak)
LINUX_FLATPAK="md.obsidian.Obsidian com.discordapp.Discord com.slack.Slack org.cryptomator.Cryptomator"

# ----------------------------------------------------------------------------
# Apps that still need a manual install (no reliable package source)
# ----------------------------------------------------------------------------
# macOS apps are now all handled by Brewfile.macos (casks + mas). Nothing manual.
MACOS_MANUAL=""
LINUX_MANUAL="1Password (https://1password.com/downloads/linux/)"

# ----------------------------------------------------------------------------
# Compute the set of stow packages for a given platform.
#   $1 = os  ("macos" | "linux")
#   $2 = gui ("true" | "false")
# ----------------------------------------------------------------------------
stow_packages() {
    local os="$1" gui="$2"
    local pkgs="$STOW_COMMON"
    if [ "$os" = "macos" ]; then
        pkgs="$pkgs $STOW_MACOS"
    elif [ "$gui" = "true" ]; then
        pkgs="$pkgs $STOW_LINUX_GUI"
    fi
    echo "$pkgs"
}
