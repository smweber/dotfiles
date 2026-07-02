#!/bin/bash
#
# Bootstrap script for fresh computer installs
# https://github.com/smweber/dotfiles
#
# Host:
#   curl -fsSL https://raw.githubusercontent.com/smweber/dotfiles/master/bootstrap.sh | bash
# Agent VM:
#   bash bootstrap.sh --profile agent-vm
#
# Package lists live in Brewfile / Brewfile.macos (brew) and packages.sh
# (stow / apt / flatpak). This script just orchestrates.
#
# Non-interactive run: bash bootstrap.sh --yes  (or ASSUME_YES=1 bash bootstrap.sh)
#

set -uo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
PROFILE="${BOOTSTRAP_PROFILE:-}"

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

# When this script is piped from curl, stdin is EOF by the time main() runs,
# so interactive child commands (installers, gh auth login, chsh) must read
# the terminal instead. Fall back to /dev/null so nothing hangs on EOF reads.
if { : < /dev/tty; } 2>/dev/null; then
    TTY_IN=/dev/tty
else
    TTY_IN=/dev/null
fi

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
    # Fresh installs / SSH sessions have no DISPLAY; an enabled display
    # manager means this machine has a desktop. (Don't trust `systemctl
    # get-default` - cloud images report graphical.target while headless.)
    if [[ -e /etc/systemd/system/display-manager.service ]]; then
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
    if [[ "$TTY_IN" != /dev/tty ]]; then
        echo "No terminal available to answer prompts - re-run with --yes." >&2
        exit 2
    fi
    REPLY=""
    read -p "[Y/n] " -n 1 -r < /dev/tty
    echo
    [[ $REPLY =~ ^[Nn]$ ]] && return 1
    return 0
}

# Run a command, echoing it first. Records (but does not abort on) failures.
run() {
    echo -e "    ${BLUE}\$${NC} $*"
    if ! "$@" < "$TTY_IN"; then
        warn "command failed: $*"
        FAILED+=("$*")
        return 1
    fi
}

# Like run, but for commands that need shell features (pipes, substitutions).
# Callers pass a single-quoted literal string; nothing user-controlled.
run_sh() {
    echo -e "    ${BLUE}\$${NC} $1"
    if ! eval "$1" < "$TTY_IN"; then
        warn "command failed: $1"
        FAILED+=("$1")
        return 1
    fi
}

# Check if command exists
has() { command -v "$1" &> /dev/null; }

# stow aborts a whole package if any target is an existing *real* file (not a
# symlink). Fresh systems ship skeleton files (Ubuntu's ~/.profile from
# /etc/skel is the usual culprit) that collide with our dotfiles, so move any
# such file aside first. With --dotfiles, a package path like sh/dot-profile
# maps to ~/.profile, and dot-config/... to .config/..., so mirror that here.
backup_stow_conflicts() {
    local pkg="$1" src rel target
    while IFS= read -r src; do
        rel="$(printf '%s' "${src#"$pkg"/}" | sed -E 's,(^|/)dot-,\1.,g')"
        target="$HOME/$rel"
        [[ -e "$target" && ! -L "$target" ]] || continue
        run mv "$target" "$target.before-dotfiles"
    done < <(find "$pkg" -type f)
}

has_claude() {
    has claude ||
        [[ -x "$HOME/.local/bin/claude" ]] ||
        [[ -x "$HOME/.claude/local/claude" ]]
}

# check_agent_tool <display name> <check command...>
# Reports whether an agent tool made it in via Brewfile.agent.
check_agent_tool() {
    local name="$1"; shift
    if "$@"; then
        info "$name is already installed"
    else
        warn "$name was not installed by Brewfile.agent"
    fi
}

usage() {
    cat <<'EOF'
Usage: bootstrap.sh [--profile host|agent-vm] [--yes]

  With no argument, /etc/devvm-agent or SMOLVM_GUEST=1 selects agent-vm.
  host      Normal laptop/VM setup. Installs smolvm, but no LLM agents.
  agent-vm  Isolated development VM. Installs Claude Code and Codex.
  --yes     Accept bootstrap questions non-interactively.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile)
                [[ $# -ge 2 ]] || { echo "--profile requires a value" >&2; exit 2; }
                PROFILE="$2"
                shift 2
                ;;
            --yes)
                ASSUME_YES=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown argument: $1" >&2
                usage >&2
                exit 2
                ;;
        esac
    done

    case "$PROFILE" in
        "") ;;
        host|agent-vm) ;;
        *)
            echo "Unknown profile: $PROFILE" >&2
            usage >&2
            exit 2
            ;;
    esac
}

detect_profile() {
    if [[ -n "$PROFILE" ]]; then
        return
    fi

    if [[ -f /etc/devvm-agent ]] || [[ "${SMOLVM_GUEST:-0}" == "1" ]]; then
        PROFILE="agent-vm"
    else
        PROFILE="host"
    fi
}

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
    parse_args "$@"
    detect_profile
    detect_os

    # NONINTERACTIVE keeps the Homebrew installer from waiting for a keypress.
    if [[ "${ASSUME_YES:-0}" == "1" ]]; then
        export ASSUME_YES NONINTERACTIVE=1
    fi

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Dotfiles Bootstrap Script                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Detected OS: ${BLUE}$OS${NC}"
    echo -e "Bootstrap profile: ${BLUE}$PROFILE${NC}"
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
    if [[ "$PROFILE" == "host" ]] && [[ "$OS" == "linux" ]] && has apt; then
        step "Update system packages"
        if ask "Update and upgrade system packages (apt)?"; then
            run sudo apt update
            run sudo apt upgrade -y
        fi
    fi

    # -------------------------------------------------------------------------
    # Hostname (interactive only - there's nothing sensible to auto-answer)
    # -------------------------------------------------------------------------
    if [[ "$PROFILE" == "host" ]] && [[ "${ASSUME_YES:-0}" != "1" ]]; then
        step "Set hostname"
        info "Current hostname: $(hostname)"
        if ask "Set a new hostname?"; then
            read -r -p "New hostname: " new_hostname < /dev/tty
            if [[ -z "$new_hostname" ]]; then
                info "No name entered, skipping"
            elif [[ "$OS" == "macos" ]]; then
                run sudo scutil --set ComputerName "$new_hostname"
                run sudo scutil --set HostName "$new_hostname"
                run sudo scutil --set LocalHostName "$new_hostname"
            else
                run sudo hostnamectl set-hostname "$new_hostname"
            fi
        fi
    fi

    # -------------------------------------------------------------------------
    # Generate SSH key
    # -------------------------------------------------------------------------
    if [[ "$PROFILE" == "host" ]]; then
        step "SSH Key Setup"
        if [[ -f ~/.ssh/id_ed25519 ]]; then
            info "SSH key already exists at ~/.ssh/id_ed25519"
        else
            info "No SSH key found at ~/.ssh/id_ed25519"
            if ask "Generate a new SSH key?"; then
                read -r -p "Enter your email for the SSH key: " email < /dev/tty
                run mkdir -p -m 700 "$HOME/.ssh"
                run ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519"
            fi
        fi
    fi

    # -------------------------------------------------------------------------
    # Install Homebrew (provides stow + cross-platform packages via Brewfile).
    # Runs before the clone: on a fresh macOS install the Homebrew installer
    # also installs the Xcode Command Line Tools, which provide git.
    # -------------------------------------------------------------------------
    step "Install Homebrew"
    if load_brew; then
        info "Homebrew is already installed"
    else
        info "Homebrew provides GNU Stow (apt's is too old) and the Brewfile packages"
        [[ "$OS" == "macos" ]] && info "Also installs the Xcode Command Line Tools (git) if missing"
        if ask "Install Homebrew?"; then
            # Expanded by the inner bash, not this shell.
            # shellcheck disable=SC2016
            run_sh '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
            load_brew
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
            run git clone https://github.com/smweber/dotfiles.git "$DOTFILES"
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
    # Install packages via Brewfile (idempotent)
    # -------------------------------------------------------------------------
    if has brew; then
        step "Install packages via Homebrew (brew bundle)"
        BREWFILES=("$DOTFILES/Brewfile")
        [[ "$OS" == "macos" ]] && BREWFILES+=("$DOTFILES/Brewfile.macos")
        [[ "$PROFILE" == "agent-vm" ]] && BREWFILES+=("$DOTFILES/Brewfile.agent")
        for f in "${BREWFILES[@]}"; do
            info "Package list: $f"
        done
        if ask "Run brew bundle?"; then
            for f in "${BREWFILES[@]}"; do
                run brew bundle --file "$f"
            done
        fi
    else
        warn "Homebrew not available - skipping brew packages and stow install"
    fi

    # -------------------------------------------------------------------------
    # Add SSH key to GitHub, then use SSH for the dotfiles remote
    # -------------------------------------------------------------------------
    if [[ "$PROFILE" == "host" ]]; then
        step "Add SSH key to GitHub"
        GITHUB_SSH_READY=false
        if [[ -f ~/.ssh/id_ed25519.pub ]]; then
            if has gh; then
                if ask "Upload SSH key to GitHub via gh?"; then
                    if gh auth status &>/dev/null || run gh auth login; then
                        LOCAL_SSH_KEY="$(awk '{print $1 " " $2}' ~/.ssh/id_ed25519.pub)"
                        # Capture first: grep -q can SIGPIPE gh, and pipefail
                        # would report a registered key as missing.
                        GITHUB_KEYS="$(gh api user/keys --paginate --jq '.[].key' 2>/dev/null |
                            awk '{print $1 " " $2}')"
                        if grep -Fqx "$LOCAL_SSH_KEY" <<< "$GITHUB_KEYS"; then
                            info "SSH key is already registered with GitHub"
                            GITHUB_SSH_READY=true
                        else
                            # Keep both GitHub's title and the public key's
                            # embedded comment descriptive. Do not rewrite the
                            # user's local .pub file.
                            SSH_KEY_UPLOAD="$(mktemp)"
                            awk -v host="$(hostname)" \
                                '{ print $1 " " $2 " " host }' \
                                ~/.ssh/id_ed25519.pub > "$SSH_KEY_UPLOAD"
                            if run gh ssh-key add "$SSH_KEY_UPLOAD" --title "$(hostname)"; then
                                GITHUB_SSH_READY=true
                            fi
                            rm -f "$SSH_KEY_UPLOAD"
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
            run git -C "$DOTFILES" remote set-url origin git@github.com:smweber/dotfiles.git
        fi
    fi

    # -------------------------------------------------------------------------
    # Colocate Jujutsu on the dotfiles checkout
    # -------------------------------------------------------------------------
    # jj shares the Git backend (colocated) so gh and git tooling keep working
    # while jj is the primary VCS. Only meaningful on a fresh clone; skip when
    # the checkout is already colocated (e.g. re-running bootstrap on the host).
    #
    # `jj git init --colocate` imports origin/master as an *untracked* remote
    # bookmark (git.auto-local-bookmark defaults to false), so without the
    # explicit track step a fresh checkout has no local master tracking origin.
    if has jj && [[ -d "$DOTFILES/.git" ]] && [[ ! -d "$DOTFILES/.jj" ]]; then
        step "Colocate Jujutsu on the dotfiles repo"
        if ask "Initialize colocated jj in $DOTFILES?"; then
            run jj git init --colocate "$DOTFILES"
            run jj -R "$DOTFILES" bookmark track master --remote=origin
        fi
    fi

    # -------------------------------------------------------------------------
    # Stow dotfiles
    # -------------------------------------------------------------------------
    step "Stow dotfiles"
    install_devvm_zsh_completion
    if has stow; then
        ALL_STOW="$(stow_packages "$OS" "$HAS_GUI")"
        info "This symlinks config files to your home directory"
        info "Packages to stow: $ALL_STOW"
        if ask "Stow these packages?"; then
            cd "$DOTFILES" || exit 1
            for pkg in $ALL_STOW; do
                if [[ -d "$pkg" ]]; then
                    backup_stow_conflicts "$pkg"
                    run stow --dotfiles --no-folding "$pkg"
                else
                    warn "$pkg: no such directory in $DOTFILES, skipping"
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
        run git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    fi

    step "Install tmux plugins"
    if [[ -f ~/.tmux/plugins/tpm/bin/install_plugins ]]; then
        if ask "Install tmux plugins?"; then
            run "$HOME/.tmux/plugins/tpm/bin/install_plugins"
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
            run nvim --headless '+Lazy! sync' +qa
        fi
    else
        info "nvim not found, skipping"
    fi

    # -------------------------------------------------------------------------
    # Machine-local profile
    # -------------------------------------------------------------------------
    # (fish stays a tmux default-command, not the login shell - see tmux.conf.)
    # config.fish parses ~/.local_profile on startup; create it so fish
    # doesn't error on a fresh machine.
    [[ -f ~/.local_profile ]] || run touch ~/.local_profile

    # -------------------------------------------------------------------------
    # Profile-specific tools
    # -------------------------------------------------------------------------
    if [[ "$PROFILE" == "host" ]]; then
        step "Install smolvm"
        if has smolvm; then
            info "smolvm is already installed"
        elif ask "Install smolvm for isolated development VMs?"; then
            run_sh 'curl -sSL https://smolmachines.com/install.sh | bash'
        fi
    else
        step "Install agent tools"
        check_agent_tool "Codex" has codex
        check_agent_tool "Claude Code" has_claude

        if has_claude && has jq; then
            step "Configure Claude Code statusline"
            CLAUDE_SETTINGS="$HOME/.claude/settings.json"
            STATUSLINE_COMMAND="$DOTFILES/bin/claude-statusline-command.sh"
            mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
            [[ -f "$CLAUDE_SETTINGS" ]] || printf '{}\n' > "$CLAUDE_SETTINGS"

            if jq -e --arg command "$STATUSLINE_COMMAND" \
                '.statusLine == {"type": "command", "command": $command}' \
                "$CLAUDE_SETTINGS" >/dev/null 2>&1; then
                info "Claude Code statusline is already configured"
            else
                CLAUDE_SETTINGS_TMP="$(mktemp)"
                if jq --arg command "$STATUSLINE_COMMAND" \
                    '.statusLine = {"type": "command", "command": $command}' \
                    "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS_TMP"; then
                    mv "$CLAUDE_SETTINGS_TMP" "$CLAUDE_SETTINGS"
                    info "Configured Claude Code statusline"
                else
                    rm -f "$CLAUDE_SETTINGS_TMP"
                    warn "Could not update $CLAUDE_SETTINGS (is it valid JSON?)"
                    FAILED+=("configure Claude Code statusline")
                fi
            fi
        elif has_claude; then
            warn "jq not found; skipping Claude Code statusline configuration"
        fi

        info "Authenticate inside this VM when ready:"
        info "  gh auth login"
        info "  codex login"
        info "  claude"
    fi

    # -------------------------------------------------------------------------
    # Linux GUI packages (apt) - not covered by Homebrew
    # -------------------------------------------------------------------------
    if [[ "$OS" == "linux" ]] && [[ "$HAS_GUI" == "true" ]] && has apt; then
        step "Install Linux GUI packages (apt)"
        info "Packages: $LINUX_GUI_APT"
        info "Nerd font: install manually on Linux (font-meslo-lg-nerd-font is a macOS cask)"
        if ask "Install Linux GUI packages?"; then
            # shellcheck disable=SC2086  # word-splitting the package list is intended
            run sudo apt install -y $LINUX_GUI_APT
        fi
    fi

    # -------------------------------------------------------------------------
    # Linux GUI software (flatpak)
    # -------------------------------------------------------------------------
    if [[ "$OS" == "linux" ]] && [[ "$HAS_GUI" == "true" ]]; then
        step "Install Linux GUI applications (flatpak)"
        info "Apps: $LINUX_FLATPAK"
        if has flatpak; then
            if ask "Install these apps via Flatpak?"; then
                run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
                for app in $LINUX_FLATPAK; do
                    run flatpak install -y flathub "$app"
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
    # paneru service (macOS scrolling window manager, installed by Brewfile.macos)
    # -------------------------------------------------------------------------
    if [[ "$OS" == "macos" ]] && has paneru; then
        step "Start paneru (scrolling window manager)"
        if ask "Register paneru as a login service and start it?"; then
            run paneru install
            run paneru start
            info "If macOS just prompted for Accessibility permission, grant it"
            info "in System Settings, then run: paneru restart"
        fi
    fi

    # -------------------------------------------------------------------------
    # macOS system preferences (defaults)
    # -------------------------------------------------------------------------
    if [[ "$OS" == "macos" ]] && [[ -f "$DOTFILES/bin/macos-defaults.sh" ]]; then
        step "Apply macOS system preferences"
        info "Keyboard, Dock, trackpad and menu-bar tweaks (see bin/macos-defaults.sh)"
        info "A few settings are marked [VERIFY] - confirm them in System Settings"
        if ask "Apply macOS defaults now?"; then
            run bash "$DOTFILES/bin/macos-defaults.sh"
        fi
    fi

    # -------------------------------------------------------------------------
    # macOS manual apps (not available via cask / needs App Store)
    # -------------------------------------------------------------------------
    if [[ "$OS" == "macos" ]] && [[ -n "$MACOS_MANUAL" ]]; then
        echo ""
        warn "Remember to install these manually (App Store / direct download):"
        info "  - $MACOS_MANUAL"
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
