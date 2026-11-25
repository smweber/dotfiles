#!/usr/bin/env bash
#
# Your devvm hook: `devvm create` and `devvm setup NAME` run this inside the
# box, as the user `dev` (passwordless sudo), after devvm's own setup. It
# started as devvm's starter and is yours now: edit it, then
# `devvm setup NAME` runs it again. Keep it safe to re-run.
#
# It runs with no terminal, so nothing here can ask a question.
set -euo pipefail

# --- Packages -------------------------------------------------------------
# The box already has git, curl, build-essential, tmux and gh.
# A new cloud server runs its own apt in the background for the first
# minutes, and `apt-get update` fails at once while that holds the lists.
tries=0
until sudo apt-get update -qq </dev/null; do
    tries=$((tries + 1))
    [ "$tries" -lt 60 ] || { echo "hook: apt-get update keeps failing" >&2; exit 1; }
    sleep 5
done
# apt is noisy: its output is shown only when the install fails.
echo "hook: installing packages"
log=$(mktemp)
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y \
    vim less ripgrep fd-find fzf jq unzip htop tree bash-completion </dev/null >"$log" 2>&1; then
    cat "$log" >&2
    exit 1
fi
rm -f "$log"

# Ubuntu installs fd as `fdfind`.
mkdir -p "$HOME/.local/bin"
if command -v fdfind >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

# --- Files this hook owns -------------------------------------------------
# write_owned FILE: write stdin to FILE, unless FILE exists without the mark
# below (then you edited it in the box, and it is left alone).
mark="# managed by your devvm hook (hook.sh); edit it there"
write_owned() {
    if [ -e "$1" ] && ! grep -qxF "$mark" "$1"; then
        echo "hook: leaving $1 alone (no longer the hook's)" >&2
        cat >/dev/null
        return
    fi
    { printf '%s\n' "$mark"; cat; } >"$1"
}

# --- tmux -----------------------------------------------------------------
# `devvm attach` is a tmux session that keeps running when you disconnect.
# The prefix stays Ctrl-b: Ctrl-b d detaches, Ctrl-b ? lists every key.
write_owned "$HOME/.tmux.conf" <<'TMUX'
# The mouse works: click a pane or window, drag a border, scroll the wheel.
set -g mouse on
set -g history-limit 50000

# Windows and panes count from 1 (the keys are in that order), no gaps.
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# Esc reaches vim at once; editors learn when the terminal gains focus.
set -sg escape-time 10
set -g focus-events on

# Ctrl-b | and Ctrl-b - split, and a new pane or window starts where you are.
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"

# Ctrl-b r reloads this file.
bind r source-file ~/.tmux.conf \; display-message "tmux.conf reloaded"

# The status line says where you are: the box's name, the user, your
# windows, and how to leave. It uses your terminal's own colours and no
# special font. Change "blue" below to recolour all of it.
set -g status-interval 15
set -g status-style "bg=default,fg=default"
set -g status-left "#[bg=blue,fg=black,bold] #h #[bg=default,fg=blue,nobold] #{user} #[fg=default]| "
set -g status-left-length 40
setw -g window-status-format " #I #W "
setw -g window-status-current-format "#[fg=blue,bold,underscore] #I #W "
setw -g window-status-separator ""
# The hint on the right; delete this line once you know it.
set -g status-right "#[dim]Ctrl-b d to detach "
set -g status-right-length 30

# The same accent for the active pane's border and tmux's own messages.
set -g pane-active-border-style "fg=blue"
set -g message-style "bg=blue,fg=black"
TMUX
# A session that is already running picks it up now (smol's tmux is on
# devvm's own socket).
tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
tmux -S "$HOME/.devvm/tmux.sock" source-file "$HOME/.tmux.conf" 2>/dev/null || true

# --- Shell ----------------------------------------------------------------
write_owned "$HOME/.bash_devvm" <<'BASH'
export EDITOR=vim
HISTSIZE=100000
HISTFILESIZE=200000
shopt -s histappend
alias ll='ls -alF'
# Ctrl-r fuzzy history, Ctrl-t fuzzy files (where the image ships fzf's
# examples: a minimal one leaves /usr/share/doc out).
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && . /usr/share/doc/fzf/examples/key-bindings.bash
BASH
grep -qF '.bash_devvm' "$HOME/.bashrc" 2>/dev/null ||
    echo '[ -f ~/.bash_devvm ] && . ~/.bash_devvm' >>"$HOME/.bashrc"

# --- Ideas ----------------------------------------------------------------
# Language runtimes, with mise (https://mise.jdx.dev):
#   curl -fsSL https://mise.run | sh
#   ~/.local/bin/mise use -g node@lts python@3.13
#
# Your dotfiles (with share_auth = ["github"] in the template, gh is
# already logged in here, so a private repo works):
#   [ -d ~/dotfiles ] || gh repo clone YOU/dotfiles ~/dotfiles
#   ~/dotfiles/install.sh

echo "hook: done"
