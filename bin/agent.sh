#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="${0##*/}"
AGENT_WORKSPACE_ROOT="${AGENT_WORKSPACE_ROOT:-$HOME/src/agent-workspaces}"
PARENT_MARKER=".jj/working_copy/agent-parent-root"
SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  _resolved_script_path="$(readlink -f "$SCRIPT_PATH" 2>/dev/null || true)"
  if [[ -n "${_resolved_script_path:-}" ]]; then
    SCRIPT_PATH="$_resolved_script_path"
  fi
fi

print_help() {
  cat <<HELP
Usage:
  $SCRIPT_NAME codex <workspace-name> [codex args...]
  $SCRIPT_NAME claude <workspace-name> [claude args...]
  $SCRIPT_NAME cleanup
  $SCRIPT_NAME status
  $SCRIPT_NAME help

Behavior:
  - In a jj repo root, 'codex' or 'claude' creates a workspace at:
      $AGENT_WORKSPACE_ROOT/<repo>/<workspace-name>
    then launches the chosen agent from that workspace.
  - In a workspace, 'cleanup' requires a clean working copy, then forgets and
    deletes the workspace created by this script.
  - In a jj repo or workspace, 'status' lists workspaces and marks the current one.
  - With no args in a jj repo/workspace, defaults to 'status' and prints this help.
HELP

  if command -v fish >/dev/null 2>&1 && ! fish_integration_installed; then
    cat <<HELP

Fish integration:
  Fish wrapper/completions are not installed.
  Run: $SCRIPT_NAME install-fish
HELP
  fi

  case "$(basename "${SHELL:-}")" in
    bash)
      if ! bash_integration_installed; then
        cat <<HELP

Bash integration:
  Wrapper/completions are not installed.
  Run: $SCRIPT_NAME install-bash
HELP
      fi
      ;;
    zsh)
      if ! zsh_integration_installed; then
        cat <<HELP

Zsh integration:
  Wrapper/completions are not installed.
  Run: $SCRIPT_NAME install-zsh
HELP
      fi
      ;;
  esac
}

print_error() {
  local message="$1"
  echo "Error: $message" >&2
  echo >&2
  print_help >&2
  exit 1
}

in_jj_repo() {
  jj root >/dev/null 2>&1
}

workspace_root() {
  jj workspace root 2>/dev/null
}

current_workspace_name() {
  local current_commit line name commit

  current_commit="$(jj log -r @ --no-graph -T 'commit_id ++ "\n"' 2>/dev/null || true)"
  if [[ -n "$current_commit" ]]; then
    while IFS=$'\t' read -r name commit; do
      if [[ -n "$name" && "$commit" == "$current_commit" ]]; then
        printf '%s\n' "$name"
        return 0
      fi
    done < <(jj workspace list --template 'name ++ "\t" ++ target.commit_id() ++ "\n"' 2>/dev/null)
  fi

  jj log -r @ --no-graph -T 'working_copies.map(|w| w.name()).join(" ")' 2>/dev/null | awk '{print $1}'
}

run_status() {
  if ! in_jj_repo; then
    print_error "'status' must be run from inside a jj repo or workspace."
  fi

  local current line name repo_root
  repo_root="$(jj root)"
  current="$(current_workspace_name || true)"

  echo "Workspaces for $repo_root:"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name="${line%%:*}"
    if [[ -n "$current" && "$name" == "$current" ]]; then
      printf '* %s\n' "$line"
    else
      printf '  %s\n' "$line"
    fi
  done < <(jj workspace list)
}

ensure_clean_workspace() {
  local state
  state="$(jj log -r @ --no-graph -T 'if(empty, "", "dirty") ++ if(conflict, " conflict", "")')"
  if [[ -n "$state" ]]; then
    print_error "Workspace is not clean. Commit, abandon, or resolve conflicts before cleanup."
  fi
}

launch_agent_workspace() {
  local agent_cmd workspace_name workspace_dir
  agent_cmd="$1"
  workspace_name="$2"
  shift 2

  if ! command -v "$agent_cmd" >/dev/null 2>&1; then
    print_error "Agent command '$agent_cmd' not found in PATH."
  fi

  workspace_dir="$(create_workspace "$workspace_name")"
  cd "$workspace_dir"
  exec "$agent_cmd" "$@"
}

create_workspace() {
  local workspace_name root cwd repo_name workspace_dir
  workspace_name="$1"

  if ! in_jj_repo; then
    print_error "Workspace creation must be run from the root of a jj repo."
  fi

  root="$(workspace_root)"
  cwd="$(pwd -P)"
  if [[ "$cwd" != "$root" ]]; then
    print_error "Workspace creation must be run from the workspace root. Current root: $root"
  fi

  if [[ -z "$workspace_name" ]]; then
    print_error "Missing workspace name."
  fi

  if [[ ! "$workspace_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    print_error "Workspace name must match [A-Za-z0-9._-]+"
  fi

  if jj workspace list --template 'name ++ "\n"' | grep -Fxq -- "$workspace_name"; then
    print_error "Workspace name '$workspace_name' already exists in this repo."
  fi

  repo_name="$(basename "$root")"
  workspace_dir="$AGENT_WORKSPACE_ROOT/$repo_name/$workspace_name"

  mkdir -p "$AGENT_WORKSPACE_ROOT/$repo_name"
  if [[ -e "$workspace_dir" ]]; then
    print_error "Destination already exists: $workspace_dir"
  fi

  jj workspace add --name "$workspace_name" "$workspace_dir" >&2
  printf '%s\n' "$root" > "$workspace_dir/$PARENT_MARKER"

  printf '%s\n' "$workspace_dir"
}

cleanup_workspace() {
  if ! in_jj_repo; then
    print_error "'cleanup' must be run from inside a workspace."
  fi

  local root current parent marker_path
  root="$(workspace_root)"
  marker_path="$root/$PARENT_MARKER"

  if [[ ! -f "$marker_path" ]]; then
    print_error "Missing $PARENT_MARKER. Cleanup only supports workspaces created by this script."
  fi

  ensure_clean_workspace

  current="$(current_workspace_name || true)"
  if [[ -z "$current" ]]; then
    print_error "Unable to determine current workspace name."
  fi

  parent="$(managed_parent_root || true)"
  if [[ -z "$parent" ]]; then
    print_error "Parent repo path is missing or invalid in $marker_path"
  fi

  cd "$parent"
  jj workspace forget "$current"
  rm -rf -- "$root"

  echo "Cleaned workspace '$current': $root"
  echo "Parent repo: $parent"
  if [[ "${AGENT_SUPPRESS_PARENT_NOTE:-0}" != "1" && "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Note: this script cannot change your parent shell directory. Run: cd \"$parent\""
  fi
}

managed_parent_root() {
  local root marker_path parent
  root="$(workspace_root || true)"
  marker_path="$root/$PARENT_MARKER"

  if [[ -z "$root" || ! -f "$marker_path" ]]; then
    return 1
  fi

  parent="$(head -n 1 "$marker_path" || true)"
  if [[ -z "$parent" || ! -d "$parent" ]]; then
    return 1
  fi

  printf '%s\n' "$parent"
}

fish_function_file() {
  printf '%s\n' "$HOME/.config/fish/functions/agent.fish"
}

fish_completion_file() {
  printf '%s\n' "$HOME/.config/fish/completions/agent.fish"
}

fish_integration_installed() {
  local function_file completion_file
  function_file="$(fish_function_file)"
  completion_file="$(fish_completion_file)"

  [[ -f "$function_file" && -f "$completion_file" ]] || return 1
  if grep -Fq 'agent.sh fish loader (auto-generated by agent.sh install-fish)' "$function_file" \
    && grep -Fq 'agent.sh fish completion loader (auto-generated by agent.sh install-fish)' "$completion_file"; then
    return 0
  fi

  if grep -Fq 'wrapper fish | source' "$function_file" \
    && grep -Fq 'completions fish | source' "$completion_file"; then
    return 0
  fi

  return 1
}

bash_integration_file() {
  printf '%s\n' "$HOME/.config/agent/agent.bash"
}

bash_startup_file() {
  printf '%s\n' "$HOME/.bashrc"
}

bash_integration_installed() {
  local integration_file startup_file
  integration_file="$(bash_integration_file)"
  startup_file="$(bash_startup_file)"

  [[ -f "$integration_file" ]] || return 1
  [[ -f "$startup_file" ]] || return 1
  grep -Fq 'agent.sh bash integration' "$startup_file" || return 1
}

zsh_integration_file() {
  printf '%s\n' "$HOME/.config/agent/agent.zsh"
}

zsh_startup_file() {
  printf '%s\n' "$HOME/.zshrc"
}

zsh_integration_installed() {
  local integration_file startup_file
  integration_file="$(zsh_integration_file)"
  startup_file="$(zsh_startup_file)"

  [[ -f "$integration_file" ]] || return 1
  [[ -f "$startup_file" ]] || return 1
  grep -Fq 'agent.sh zsh integration' "$startup_file" || return 1
}

append_startup_integration_block() {
  local startup_file shell_name source_line start_marker end_marker
  startup_file="$1"
  shell_name="$2"
  source_line="$3"
  start_marker="# >>> agent.sh $shell_name integration >>>"
  end_marker="# <<< agent.sh $shell_name integration <<<"

  touch "$startup_file"
  if grep -Fq "$start_marker" "$startup_file"; then
    return 0
  fi

  {
    printf '\n%s\n' "$start_marker"
    printf '%s\n' "$source_line"
    printf '%s\n' "$end_marker"
  } >> "$startup_file"
}

print_fish_wrapper() {
  local script_path_escaped
  script_path_escaped="$(printf '%s' "$SCRIPT_PATH" | sed 's/[\\"]/\\&/g')"
  cat <<FISH
# agent.sh fish loader (auto-generated by agent.sh install-fish)
function agent --description "Manage jj workspaces for coding agents"
    set -l script "$script_path_escaped"

    if test ! -x "\$script"
        echo "agent: missing executable \$script" >&2
        return 1
    end

    if test (count \$argv) -ge 1
        if contains -- "\$argv[1]" codex claude
            if test (count \$argv) -lt 2
                echo "agent: missing workspace name for \$argv[1]" >&2
                return 1
            end

            set -l workspace_dir (command "\$script" prepare-workspace "\$argv[2]")
            set -l prepare_status \$status
            if test \$prepare_status -ne 0
                return \$prepare_status
            end

            cd "\$workspace_dir"
            command "\$argv[1]" \$argv[3..-1]
            return \$status
        end

        if test "\$argv[1]" = "cleanup"
            set -l parent (command "\$script" parent-root 2>/dev/null)
            env AGENT_SUPPRESS_PARENT_NOTE=1 "\$script" \$argv
            set -l exit_code \$status

            if test \$exit_code -eq 0; and test -n "\$parent"; and test -d "\$parent"
                cd "\$parent"
            end

            return \$exit_code
        end
    end

    command "\$script" \$argv
end
FISH
}

print_fish_completions() {
  local script_path_escaped
  script_path_escaped="$(printf '%s' "$SCRIPT_PATH" | sed 's/[\\"]/\\&/g')"
  cat <<FISH
# agent.sh fish completion loader (auto-generated by agent.sh install-fish)
function __agent_in_jj_repo
    command jj root >/dev/null 2>/dev/null
end

function __agent_in_managed_workspace
    set -l script "$script_path_escaped"
    test -x "\$script"; and command "\$script" parent-root >/dev/null 2>/dev/null
end

function __agent_existing_workspaces
    command jj workspace list --template 'name ++ "\n"' 2>/dev/null
end

set -l __agent_subcommands codex claude cleanup status help

complete -c agent -f -n "not __fish_seen_subcommand_from \$__agent_subcommands" -a codex -d "Create workspace and launch Codex"
complete -c agent -f -n "not __fish_seen_subcommand_from \$__agent_subcommands" -a claude -d "Create workspace and launch Claude Code"
complete -c agent -f -n "not __fish_seen_subcommand_from \$__agent_subcommands; and __agent_in_managed_workspace" -a cleanup -d "Forget and delete current managed workspace"
complete -c agent -f -n "not __fish_seen_subcommand_from \$__agent_subcommands; and __agent_in_jj_repo" -a status -d "List JJ workspaces"
complete -c agent -f -n "not __fish_seen_subcommand_from \$__agent_subcommands" -a help -d "Show help"

complete -c agent -f -n "__fish_seen_subcommand_from codex claude; and test (count (commandline -opc)) -eq 2" -a "(__agent_existing_workspaces)"
FISH
}

print_bash_wrapper() {
  local escaped_script_path
  escaped_script_path="$(printf '%s' "$SCRIPT_PATH" | sed -e 's/[\\&@]/\\&/g')"

  cat <<'BASH' | sed -e "s@__AGENT_SCRIPT__@$escaped_script_path@g"
# agent.sh bash wrapper (auto-generated by agent.sh install-bash)
agent() {
  local script="__AGENT_SCRIPT__"

  if [[ ! -x "$script" ]]; then
    echo "agent: missing executable $script" >&2
    return 1
  fi

  if [[ "${1:-}" == "codex" || "${1:-}" == "claude" ]]; then
    local agent_cmd workspace_name workspace_dir
    agent_cmd="${1:-}"
    workspace_name="${2:-}"

    if [[ -z "$workspace_name" ]]; then
      echo "agent: missing workspace name for $agent_cmd" >&2
      return 1
    fi

    workspace_dir="$("$script" prepare-workspace "$workspace_name")" || return $?
    cd "$workspace_dir" || return $?
    shift 2
    command "$agent_cmd" "$@"
    return $?
  fi

  if [[ "${1:-}" == "cleanup" ]]; then
    local parent exit_code
    parent="$("$script" parent-root 2>/dev/null || true)"
    AGENT_SUPPRESS_PARENT_NOTE=1 "$script" "$@"
    exit_code=$?

    if [[ $exit_code -eq 0 && -n "$parent" && -d "$parent" ]]; then
      cd "$parent" || return $exit_code
    fi

    return $exit_code
  fi

  "$script" "$@"
}
BASH
}

print_bash_completions() {
  cat <<'BASH'
# agent.sh bash completions (auto-generated by agent.sh install-bash)
_agent_complete() {
  local cur cmd
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  cmd="${COMP_WORDS[1]:-}"

  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "codex claude cleanup status help" -- "$cur") )
    return 0
  fi

  if [[ $COMP_CWORD -eq 2 && ( "$cmd" == "codex" || "$cmd" == "claude" ) ]]; then
    if command -v jj >/dev/null 2>&1; then
      local workspaces
      workspaces="$(jj workspace list --template 'name ++ "\n"' 2>/dev/null)"
      COMPREPLY=( $(compgen -W "$workspaces" -- "$cur") )
    fi
    return 0
  fi
}

complete -o default -F _agent_complete agent
BASH
}

print_zsh_wrapper() {
  local escaped_script_path
  escaped_script_path="$(printf '%s' "$SCRIPT_PATH" | sed -e 's/[\\&@]/\\&/g')"

  cat <<'ZSH' | sed -e "s@__AGENT_SCRIPT__@$escaped_script_path@g"
# agent.sh zsh wrapper (auto-generated by agent.sh install-zsh)
agent() {
  local script="__AGENT_SCRIPT__"

  if [[ ! -x "$script" ]]; then
    echo "agent: missing executable $script" >&2
    return 1
  fi

  if [[ "${1:-}" == "codex" || "${1:-}" == "claude" ]]; then
    local agent_cmd workspace_name workspace_dir
    agent_cmd="${1:-}"
    workspace_name="${2:-}"

    if [[ -z "$workspace_name" ]]; then
      echo "agent: missing workspace name for $agent_cmd" >&2
      return 1
    fi

    workspace_dir="$("$script" prepare-workspace "$workspace_name")" || return $?
    cd "$workspace_dir" || return $?
    shift 2
    command "$agent_cmd" "$@"
    return $?
  fi

  if [[ "${1:-}" == "cleanup" ]]; then
    local parent exit_code
    parent="$("$script" parent-root 2>/dev/null || true)"
    AGENT_SUPPRESS_PARENT_NOTE=1 "$script" "$@"
    exit_code=$?

    if [[ $exit_code -eq 0 && -n "$parent" && -d "$parent" ]]; then
      cd "$parent" || return $exit_code
    fi

    return $exit_code
  fi

  "$script" "$@"
}
ZSH
}

print_zsh_completions() {
  cat <<'ZSH'
# agent.sh zsh completions (auto-generated by agent.sh install-zsh)
#compdef agent

_agent() {
  local -a subcommands workspaces
  subcommands=(
    'codex:Create workspace and launch Codex'
    'claude:Create workspace and launch Claude Code'
    'cleanup:Forget and delete current managed workspace'
    'status:List JJ workspaces'
    'help:Show help'
  )

  if (( CURRENT == 2 )); then
    _describe -t commands 'agent commands' subcommands
    return
  fi

  if [[ "${words[2]}" == "codex" || "${words[2]}" == "claude" ]]; then
    if (( CURRENT == 3 )); then
      if (( $+commands[jj] )); then
        workspaces=("${(@f)$(jj workspace list --template 'name ++ "\n"' 2>/dev/null)}")
        compadd -a workspaces
      fi
    fi
  fi
}

compdef _agent agent
ZSH
}

install_fish_integration() {
  local functions_dir completions_dir function_file completion_file
  function_file="$(fish_function_file)"
  completion_file="$(fish_completion_file)"
  functions_dir="$(dirname "$function_file")"
  completions_dir="$(dirname "$completion_file")"

  mkdir -p "$functions_dir" "$completions_dir"
  print_fish_wrapper > "$function_file"
  print_fish_completions > "$completion_file"

  echo "Installed fish wrapper: $function_file"
  echo "Installed fish completions: $completion_file"
  echo "Reload fish with: exec fish"
}

install_bash_integration() {
  local integration_file startup_file integration_dir
  integration_file="$(bash_integration_file)"
  startup_file="$(bash_startup_file)"
  integration_dir="$(dirname "$integration_file")"

  mkdir -p "$integration_dir"
  {
    print_bash_wrapper
    echo
    print_bash_completions
  } > "$integration_file"

  append_startup_integration_block \
    "$startup_file" \
    "bash" \
    '[ -f "$HOME/.config/agent/agent.bash" ] && source "$HOME/.config/agent/agent.bash"'

  echo "Installed bash integration: $integration_file"
  echo "Updated startup file: $startup_file"
  echo "Reload bash with: exec bash"
}

install_zsh_integration() {
  local integration_file startup_file integration_dir
  integration_file="$(zsh_integration_file)"
  startup_file="$(zsh_startup_file)"
  integration_dir="$(dirname "$integration_file")"

  mkdir -p "$integration_dir"
  {
    print_zsh_wrapper
    echo
    print_zsh_completions
  } > "$integration_file"

  append_startup_integration_block \
    "$startup_file" \
    "zsh" \
    '[[ -f "$HOME/.config/agent/agent.zsh" ]] && source "$HOME/.config/agent/agent.zsh"'

  echo "Installed zsh integration: $integration_file"
  echo "Updated startup file: $startup_file"
  echo "Reload zsh with: exec zsh"
}

main() {
  local cmd
  cmd="${1:-}"

  if [[ -z "$cmd" ]]; then
    if in_jj_repo; then
      run_status
      echo
      print_help
      exit 0
    fi
    print_error "No command provided and current directory is not in a jj repo."
  fi

  case "$cmd" in
    install-bash)
      if [[ $# -ne 1 ]]; then
        print_error "'install-bash' does not take extra arguments."
      fi
      install_bash_integration
      ;;
    install-zsh)
      if [[ $# -ne 1 ]]; then
        print_error "'install-zsh' does not take extra arguments."
      fi
      install_zsh_integration
      ;;
    install-fish)
      if [[ $# -ne 1 ]]; then
        print_error "'install-fish' does not take extra arguments."
      fi
      install_fish_integration
      ;;
    completions)
      if [[ $# -ne 2 ]]; then
        print_error "'completions' expects one shell name, for example: completions fish"
      fi
      case "$2" in
        fish)
          print_fish_completions
          ;;
        bash)
          print_bash_completions
          ;;
        zsh)
          print_zsh_completions
          ;;
        *)
          print_error "Unsupported shell for completions: $2"
          ;;
      esac
      ;;
    wrapper)
      if [[ $# -ne 2 ]]; then
        print_error "'wrapper' expects one shell name, for example: wrapper fish"
      fi
      case "$2" in
        fish)
          print_fish_wrapper
          ;;
        bash)
          print_bash_wrapper
          ;;
        zsh)
          print_zsh_wrapper
          ;;
        *)
          print_error "Unsupported shell for wrapper: $2"
          ;;
      esac
      ;;
    parent-root)
      if [[ $# -ne 1 ]]; then
        print_error "'parent-root' does not take extra arguments."
      fi
      managed_parent_root
      ;;
    prepare-workspace)
      if [[ $# -ne 2 ]]; then
        print_error "'prepare-workspace' expects a workspace name."
      fi
      create_workspace "$2"
      ;;
    help|-h|--help)
      print_help
      ;;
    status)
      if [[ $# -ne 1 ]]; then
        print_error "'status' does not take extra arguments."
      fi
      run_status
      ;;
    cleanup)
      if [[ $# -ne 1 ]]; then
        print_error "'cleanup' does not take extra arguments."
      fi
      cleanup_workspace
      ;;
    codex|claude)
      if [[ $# -lt 2 ]]; then
        print_error "Missing workspace name for '$cmd'."
      fi
      launch_agent_workspace "$cmd" "$2" "${@:3}"
      ;;
    *)
      print_error "Unknown command: $cmd"
      ;;
  esac
}

main "$@"
