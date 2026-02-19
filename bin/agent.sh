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
  $SCRIPT_NAME fish <workspace-name> [fish args...]
  $SCRIPT_NAME switch [workspace-name]
  $SCRIPT_NAME cleanup
  $SCRIPT_NAME status [--compact] [--no-color]
  $SCRIPT_NAME help

Behavior:
  - In a jj repo root, 'codex', 'claude', or 'fish' creates a workspace at:
      $AGENT_WORKSPACE_ROOT/<repo>/<workspace-name>
    then launches the chosen agent from that workspace.
  - In a workspace, 'cleanup' requires a clean working copy, then forgets and
    deletes the workspace created by this script.
  - In a jj repo or workspace, 'switch' moves to an existing workspace.
    If no workspace name is provided, it prompts you to pick one interactively.
  - In a jj repo or workspace, 'status' shows each workspace, marks the current one,
    reports non-empty commits diverged from 'default', and lists running agents.
    Options: --compact (single-line rows), --no-color (disable ANSI colors).
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
  jj --ignore-working-copy root >/dev/null 2>&1
}

workspace_root() {
  jj --ignore-working-copy workspace root 2>/dev/null
}

current_workspace_name() {
  local current_commit line name commit

  current_commit="$(jj --ignore-working-copy log -r @ --no-graph -T 'commit_id ++ "\n"' 2>/dev/null || true)"
  if [[ -n "$current_commit" ]]; then
    while IFS=$'\t' read -r name commit; do
      if [[ -n "$name" && "$commit" == "$current_commit" ]]; then
        printf '%s\n' "$name"
        return 0
      fi
    done < <(jj --ignore-working-copy workspace list --template 'name ++ "\t" ++ target.commit_id() ++ "\n"' 2>/dev/null)
  fi

  jj --ignore-working-copy log -r @ --no-graph -T 'working_copies.map(|w| w.name()).join(" ")' 2>/dev/null | awk '{print $1}'
}

canonicalize_path() {
  local path="$1"
  (
    cd "$path" >/dev/null 2>&1
    pwd -P
  )
}

process_cwd() {
  local pid="$1" cwd

  if [[ -L "/proc/$pid/cwd" ]]; then
    cwd="$(readlink "/proc/$pid/cwd" 2>/dev/null || true)"
    if [[ -n "$cwd" && -d "$cwd" ]]; then
      printf '%s\n' "$cwd"
      return 0
    fi
  fi

  if command -v lsof >/dev/null 2>&1; then
    cwd="$(
      lsof -a -d cwd -p "$pid" -Fn 2>/dev/null \
        | awk '/^n/ {print substr($0, 2); exit}'
    )"
    if [[ -n "$cwd" && -d "$cwd" ]]; then
      printf '%s\n' "$cwd"
      return 0
    fi
  fi

  return 1
}

append_unique_csv() {
  local existing="$1" value="$2"

  if [[ -z "$existing" ]]; then
    printf '%s\n' "$value"
    return 0
  fi

  case ",$existing," in
    *",$value,"*)
      printf '%s\n' "$existing"
      ;;
    *)
      printf '%s, %s\n' "$existing" "$value"
      ;;
  esac
}

count_diverged_nonempty_commits() {
  local workspace_commit="$1" default_commit="$2" count

  count="$(
    jj --ignore-working-copy log -r "(::${workspace_commit} ~ ::${default_commit}) & ~empty()" \
      --no-graph \
      -T '"1\n"' \
      2>/dev/null \
      | wc -l \
      | tr -d '[:space:]'
  )"
  printf '%s\n' "${count:-0}"
}

run_status() {
  local status_compact status_no_color
  status_compact=0
  status_no_color=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --compact)
        status_compact=1
        ;;
      --no-color)
        status_no_color=1
        ;;
      *)
        print_error "Unsupported option for 'status': $1"
        ;;
    esac
    shift
  done

  if ! in_jj_repo; then
    print_error "'status' must be run from inside a jj repo or workspace."
  fi

  local current repo_root i default_commit default_workspace_found unknown_agents
  local name commit_short empty_state commit_id workspace_root cwd pid agent_name
  local marker changes_label agents_label
  local name_width commit_width state_width changes_width agents_width
  local header_cur header_name header_commit header_state header_changes header_agents
  local cur_cell name_cell commit_cell state_cell changes_cell agents_cell
  local row_cur row_name row_commit row_state row_changes row_agents separator
  local use_color c_reset c_bold c_dim c_green c_yellow c_red c_cyan c_blue
  local -a workspace_names=() workspace_commit_shorts=() workspace_empty_states=() workspace_commit_ids=()
  local -a workspace_roots=() workspace_changes=() workspace_agents=()

  use_color=0
  c_reset=""
  c_bold=""
  c_dim=""
  c_green=""
  c_yellow=""
  c_red=""
  c_cyan=""
  c_blue=""
  if [[ "$status_no_color" -eq 0 && -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
    use_color=1
    c_reset=$'\033[0m'
    c_bold=$'\033[1m'
    c_dim=$'\033[2m'
    c_green=$'\033[32m'
    c_yellow=$'\033[33m'
    c_red=$'\033[31m'
    c_cyan=$'\033[36m'
    c_blue=$'\033[34m'
  fi

  repo_root="$(jj --ignore-working-copy root)"
  current="$(current_workspace_name || true)"

  while IFS=$'\t' read -r name commit_short empty_state commit_id; do
    [[ -z "$name" ]] && continue
    workspace_names+=("$name")
    workspace_commit_shorts+=("$commit_short")
    workspace_empty_states+=("$empty_state")
    workspace_commit_ids+=("$commit_id")
  done < <(
    jj --ignore-working-copy workspace list \
      --template 'name ++ "\t" ++ target.change_id().short(8) ++ "\t" ++ if(target.empty(), "empty", "non-empty") ++ "\t" ++ target.commit_id() ++ "\n"'
  )

  if [[ "${#workspace_names[@]}" -eq 0 ]]; then
    echo "Workspaces for $repo_root:"
    echo "  (none)"
    return 0
  fi

  default_workspace_found=0
  default_commit=""

  for ((i = 0; i < ${#workspace_names[@]}; i++)); do
    name="${workspace_names[$i]}"
    if [[ "$name" == "default" ]]; then
      default_workspace_found=1
      default_commit="${workspace_commit_ids[$i]}"
    fi

    workspace_root="$(jj --ignore-working-copy workspace root --name "$name" 2>/dev/null || true)"
    if [[ -n "$workspace_root" ]]; then
      workspace_root="$(canonicalize_path "$workspace_root" || true)"
    fi
    workspace_roots+=("$workspace_root")
  done

  for ((i = 0; i < ${#workspace_names[@]}; i++)); do
    if [[ "$default_workspace_found" -ne 1 ]]; then
      workspace_changes+=("unknown (no default workspace)")
      continue
    fi

    name="${workspace_names[$i]}"
    if [[ "$name" == "default" ]]; then
      workspace_changes+=("base")
      continue
    fi

    changes_label="$(count_diverged_nonempty_commits "${workspace_commit_ids[$i]}" "$default_commit")"
    if [[ "$changes_label" == "0" ]]; then
      workspace_changes+=("clean")
    elif [[ "$changes_label" == "1" ]]; then
      workspace_changes+=("1 non-empty commit")
    else
      workspace_changes+=("$changes_label non-empty commits")
    fi
  done

  for ((i = 0; i < ${#workspace_names[@]}; i++)); do
    workspace_agents+=("")
  done

  unknown_agents=0
  while IFS=$'\t' read -r pid agent_name; do
    [[ -z "$pid" || -z "$agent_name" ]] && continue
    cwd="$(process_cwd "$pid" || true)"
    if [[ -z "$cwd" ]]; then
      unknown_agents=$((unknown_agents + 1))
      continue
    fi

    cwd="$(canonicalize_path "$cwd" || true)"
    [[ -z "$cwd" ]] && continue

    for ((i = 0; i < ${#workspace_names[@]}; i++)); do
      workspace_root="${workspace_roots[$i]}"
      [[ -z "$workspace_root" ]] && continue
      if [[ "$cwd" == "$workspace_root" || "$cwd" == "$workspace_root/"* ]]; then
        workspace_agents[$i]="$(append_unique_csv "${workspace_agents[$i]}" "$agent_name")"
      fi
    done
  done < <(ps -eo pid=,comm= | awk '$2=="codex" || $2=="claude" {print $1 "\t" $2}')

  echo "Workspaces for $repo_root:"

  if [[ "$status_compact" -eq 1 ]]; then
    for ((i = 0; i < ${#workspace_names[@]}; i++)); do
      name="${workspace_names[$i]}"
      if [[ -n "$current" && "$name" == "$current" ]]; then
        marker='*'
      else
        marker=' '
      fi

      agents_label="${workspace_agents[$i]}"
      if [[ -z "$agents_label" ]]; then
        agents_label="none"
      fi

      row_cur="$marker"
      row_name="$name"
      row_state="${workspace_empty_states[$i]}"
      row_changes="${workspace_changes[$i]}"
      row_agents="$agents_label"

      if [[ "$use_color" -eq 1 ]]; then
        if [[ "$marker" == "*" ]]; then
          row_cur="${c_green}${c_bold}${marker}${c_reset}"
          row_name="${c_cyan}${c_bold}${name}${c_reset}"
        fi

        if [[ "${workspace_empty_states[$i]}" == "empty" ]]; then
          row_state="${c_dim}${workspace_empty_states[$i]}${c_reset}"
        else
          row_state="${c_yellow}${workspace_empty_states[$i]}${c_reset}"
        fi

        case "${workspace_changes[$i]}" in
          clean)
            row_changes="${c_green}${workspace_changes[$i]}${c_reset}"
            ;;
          base)
            row_changes="${c_cyan}${workspace_changes[$i]}${c_reset}"
            ;;
          unknown*)
            row_changes="${c_red}${workspace_changes[$i]}${c_reset}"
            ;;
          *)
            row_changes="${c_yellow}${workspace_changes[$i]}${c_reset}"
            ;;
        esac

        if [[ "$agents_label" == "none" ]]; then
          row_agents="${c_dim}${agents_label}${c_reset}"
        else
          row_agents="${c_blue}${agents_label}${c_reset}"
        fi
      fi

      printf '  %s %s: %s (%s) | changes: %s | agents: %s\n' \
        "$row_cur" \
        "$row_name" \
        "${workspace_commit_shorts[$i]}" \
        "$row_state" \
        "$row_changes" \
        "$row_agents"
    done

    if [[ "$unknown_agents" -gt 0 ]]; then
      if [[ "$use_color" -eq 1 ]]; then
        echo "  ${c_dim}note: $unknown_agents detected codex/claude process(es) could not be mapped to a workspace (process inspection permission denied).${c_reset}"
      else
        echo "  note: $unknown_agents detected codex/claude process(es) could not be mapped to a workspace (process inspection permission denied)."
      fi
    fi
    return 0
  fi

  name_width=9
  commit_width=8
  state_width=5
  changes_width=18
  agents_width=14
  for ((i = 0; i < ${#workspace_names[@]}; i++)); do
    name="${workspace_names[$i]}"
    commit_short="${workspace_commit_shorts[$i]}"
    empty_state="${workspace_empty_states[$i]}"
    changes_label="${workspace_changes[$i]}"
    agents_label="${workspace_agents[$i]}"
    [[ -z "$agents_label" ]] && agents_label="none"

    (( ${#name} > name_width )) && name_width=${#name}
    (( ${#commit_short} > commit_width )) && commit_width=${#commit_short}
    (( ${#empty_state} > state_width )) && state_width=${#empty_state}
    (( ${#changes_label} > changes_width )) && changes_width=${#changes_label}
    (( ${#agents_label} > agents_width )) && agents_width=${#agents_label}
  done

  printf -v header_cur "%-3s" "CUR"
  printf -v header_name "%-*s" "$name_width" "WORKSPACE"
  printf -v header_commit "%-*s" "$commit_width" "CHANGE"
  printf -v header_state "%-*s" "$state_width" "STATE"
  printf -v header_changes "%-*s" "$changes_width" "CHANGES VS DEFAULT"
  printf -v header_agents "%-*s" "$agents_width" "RUNNING AGENTS"
  printf '  %s  %s  %s  %s  %s  %s\n' \
    "${c_bold}${header_cur}${c_reset}" \
    "${c_bold}${header_name}${c_reset}" \
    "${c_bold}${header_commit}${c_reset}" \
    "${c_bold}${header_state}${c_reset}" \
    "${c_bold}${header_changes}${c_reset}" \
    "${c_bold}${header_agents}${c_reset}"

  printf -v separator '%*s' $((3 + name_width + commit_width + state_width + changes_width + agents_width + 10)) ''
  separator="${separator// /-}"
  if [[ "$use_color" -eq 1 ]]; then
    printf '  %s%s%s\n' "$c_dim" "$separator" "$c_reset"
  else
    printf '  %s\n' "$separator"
  fi

  for ((i = 0; i < ${#workspace_names[@]}; i++)); do
    name="${workspace_names[$i]}"
    if [[ -n "$current" && "$name" == "$current" ]]; then
      marker='*'
    else
      marker=' '
    fi

    agents_label="${workspace_agents[$i]}"
    if [[ -z "$agents_label" ]]; then
      agents_label="none"
    fi

    printf -v cur_cell "%-3s" "$marker"
    printf -v name_cell "%-*s" "$name_width" "$name"
    printf -v commit_cell "%-*s" "$commit_width" "${workspace_commit_shorts[$i]}"
    printf -v state_cell "%-*s" "$state_width" "${workspace_empty_states[$i]}"
    printf -v changes_cell "%-*s" "$changes_width" "${workspace_changes[$i]}"
    printf -v agents_cell "%-*s" "$agents_width" "$agents_label"

    row_cur="$cur_cell"
    row_name="$name_cell"
    row_commit="$commit_cell"
    row_state="$state_cell"
    row_changes="$changes_cell"
    row_agents="$agents_cell"

    if [[ "$use_color" -eq 1 ]]; then
      if [[ "$marker" == "*" ]]; then
        row_cur="${c_green}${c_bold}${cur_cell}${c_reset}"
        row_name="${c_cyan}${c_bold}${name_cell}${c_reset}"
      fi

      if [[ "${workspace_empty_states[$i]}" == "empty" ]]; then
        row_state="${c_dim}${state_cell}${c_reset}"
      else
        row_state="${c_yellow}${state_cell}${c_reset}"
      fi

      case "${workspace_changes[$i]}" in
        clean)
          row_changes="${c_green}${changes_cell}${c_reset}"
          ;;
        base)
          row_changes="${c_cyan}${changes_cell}${c_reset}"
          ;;
        unknown*)
          row_changes="${c_red}${changes_cell}${c_reset}"
          ;;
        *)
          row_changes="${c_yellow}${changes_cell}${c_reset}"
          ;;
      esac

      if [[ "$agents_label" == "none" ]]; then
        row_agents="${c_dim}${agents_cell}${c_reset}"
      else
        row_agents="${c_blue}${agents_cell}${c_reset}"
      fi
    fi

    printf '  %s  %s  %s  %s  %s  %s\n' \
      "$row_cur" \
      "$row_name" \
      "$row_commit" \
      "$row_state" \
      "$row_changes" \
      "$row_agents"
  done

  if [[ "$unknown_agents" -gt 0 ]]; then
    if [[ "$use_color" -eq 1 ]]; then
      echo "  ${c_dim}note: $unknown_agents detected codex/claude process(es) could not be mapped to a workspace (process inspection permission denied).${c_reset}"
    else
      echo "  note: $unknown_agents detected codex/claude process(es) could not be mapped to a workspace (process inspection permission denied)."
    fi
  fi
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

  if command -v mise >/dev/null 2>&1; then
    (
      cd "$workspace_dir"
      mise trust
    ) >&2
  fi

  printf '%s\n' "$workspace_dir"
}

workspace_exists() {
  local workspace_name
  workspace_name="$1"
  jj --ignore-working-copy workspace list --template 'name ++ "\n"' | grep -Fxq -- "$workspace_name"
}

workspace_path_for_name() {
  local workspace_name workspace_dir current_name
  workspace_name="$1"
  workspace_dir="$(jj --ignore-working-copy workspace root --name "$workspace_name" 2>/dev/null || true)"

  if [[ -z "$workspace_dir" ]]; then
    current_name="$(current_workspace_name || true)"
    if [[ -n "$current_name" && "$workspace_name" == "$current_name" ]]; then
      workspace_dir="$(workspace_root || true)"
    fi
  fi

  if [[ -z "$workspace_dir" && "$workspace_name" == "default" ]]; then
    workspace_dir="$(managed_parent_root || true)"
  fi

  if [[ -z "$workspace_dir" || ! -d "$workspace_dir" ]]; then
    return 1
  fi
  canonicalize_path "$workspace_dir"
}

running_agents_for_workspace_root() {
  local target_root pid agent_name cwd agents
  target_root="$1"
  agents=""

  if [[ -z "$target_root" ]]; then
    printf '\n'
    return 0
  fi

  target_root="$(canonicalize_path "$target_root" || true)"
  if [[ -z "$target_root" ]]; then
    printf '\n'
    return 0
  fi

  while IFS=$'\t' read -r pid agent_name; do
    [[ -z "$pid" || -z "$agent_name" ]] && continue
    cwd="$(process_cwd "$pid" || true)"
    [[ -z "$cwd" ]] && continue

    cwd="$(canonicalize_path "$cwd" || true)"
    [[ -z "$cwd" ]] && continue

    if [[ "$cwd" == "$target_root" || "$cwd" == "$target_root/"* ]]; then
      agents="$(append_unique_csv "$agents" "$agent_name")"
    fi
  done < <(ps -eo pid=,comm= | awk '$2=="codex" || $2=="claude" {print $1 "\t" $2}')

  printf '%s\n' "$agents"
}

pick_workspace_interactive() {
  local name root agents label reply
  local index total use_dev_tty tty_fd
  local -a workspace_names=() workspace_labels=()

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue

    root="$(workspace_path_for_name "$name" || true)"
    if [[ -n "$root" ]]; then
      agents="$(running_agents_for_workspace_root "$root")"
    else
      agents=""
    fi

    if [[ -n "$agents" ]]; then
      label="$name (running: $agents)"
    else
      label="$name (running: none)"
    fi

    workspace_names+=("$name")
    workspace_labels+=("$label")
  done < <(jj --ignore-working-copy workspace list --template 'name ++ "\n"')

  if [[ "${#workspace_names[@]}" -eq 0 ]]; then
    print_error "No workspaces found in this repo."
  fi

  use_dev_tty=0
  tty_fd=""
  if (exec 3<>/dev/tty) 2>/dev/null && exec {tty_fd}<>/dev/tty 2>/dev/null; then
    use_dev_tty=1
  elif [[ ! -t 0 || ! -t 2 ]]; then
    print_error "No workspace specified and no interactive terminal is available."
  fi

  total="${#workspace_names[@]}"
  if [[ "$use_dev_tty" -eq 1 ]]; then
    printf 'Select workspace to switch to:\n' >&"$tty_fd"
    for ((index = 0; index < total; index++)); do
      printf '  %d) %s\n' "$((index + 1))" "${workspace_labels[$index]}" >&"$tty_fd"
    done

    while true; do
      printf 'Workspace number: ' >&"$tty_fd"
      if ! IFS= read -r reply <&"$tty_fd"; then
        exec {tty_fd}>&-
        return 1
      fi
      if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= total )); then
        printf '%s\n' "${workspace_names[$((reply - 1))]}"
        exec {tty_fd}>&-
        return 0
      fi
      printf 'Invalid selection. Enter a listed number.\n' >&"$tty_fd"
    done
  fi

  echo "Select workspace to switch to:" >&2
  for ((index = 0; index < total; index++)); do
    printf '  %d) %s\n' "$((index + 1))" "${workspace_labels[$index]}" >&2
  done

  while true; do
    printf 'Workspace number: ' >&2
    if ! IFS= read -r reply; then
      return 1
    fi
    if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= total )); then
      printf '%s\n' "${workspace_names[$((reply - 1))]}"
      return 0
    fi
    echo "Invalid selection. Enter a listed number." >&2
  done

  return 1
}

resolve_switch_target() {
  local workspace_name workspace_dir running_agents
  workspace_name="${1:-}"

  if ! in_jj_repo; then
    print_error "'switch' must be run from inside a jj repo or workspace."
  fi

  if [[ -z "$workspace_name" ]]; then
    workspace_name="$(pick_workspace_interactive || true)"
    if [[ -z "$workspace_name" ]]; then
      print_error "No workspace selected."
    fi
  fi

  if ! workspace_exists "$workspace_name"; then
    print_error "Workspace '$workspace_name' does not exist in this repo."
  fi

  workspace_dir="$(workspace_path_for_name "$workspace_name" || true)"
  if [[ -z "$workspace_dir" ]]; then
    print_error "Unable to locate workspace directory for '$workspace_name'."
  fi

  running_agents="$(running_agents_for_workspace_root "$workspace_dir")"
  if [[ -n "$running_agents" ]]; then
    echo "Info: workspace '$workspace_name' has running agent(s): $running_agents" >&2
  fi

  printf '%s\n' "$workspace_dir"
}

switch_workspace() {
  local workspace_name workspace_dir
  workspace_name="${1:-}"
  workspace_dir="$(resolve_switch_target "$workspace_name")"

  echo "Switch target: $workspace_dir"
  if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Note: this script cannot change your parent shell directory. Run: cd \"$workspace_dir\""
  fi
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
        if contains -- "\$argv[1]" codex claude fish
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

        if test "\$argv[1]" = "switch"
            set -l workspace_dir (command "\$script" switch-target \$argv[2..-1])
            set -l switch_status \$status
            if test \$switch_status -ne 0
                return \$switch_status
            end

            cd "\$workspace_dir"
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

set -l __agent_subcommands codex claude fish switch cleanup status help

complete -c agent -f -n "not __fish_seen_subcommand_from \$__agent_subcommands" -a codex -d "Create workspace and launch Codex"
complete -c agent -f -n "not __fish_seen_subcommand_from \$__agent_subcommands" -a claude -d "Create workspace and launch Claude Code"
complete -c agent -f -n "not __fish_seen_subcommand_from \$__agent_subcommands" -a fish -d "Create workspace and launch Fish shell"
complete -c agent -f -n "not __fish_seen_subcommand_from \$__agent_subcommands" -a switch -d "Switch to an existing workspace"
complete -c agent -f -n "not __fish_seen_subcommand_from \$__agent_subcommands; and __agent_in_managed_workspace" -a cleanup -d "Forget and delete current managed workspace"
complete -c agent -f -n "not __fish_seen_subcommand_from \$__agent_subcommands; and __agent_in_jj_repo" -a status -d "Show JJ workspace status"
complete -c agent -f -n "not __fish_seen_subcommand_from \$__agent_subcommands" -a help -d "Show help"
complete -c agent -f -n "__fish_seen_subcommand_from status" -l compact -d "Compact status output"
complete -c agent -f -n "__fish_seen_subcommand_from status" -l no-color -d "Disable color in status output"

complete -c agent -f -n "__fish_seen_subcommand_from codex claude fish switch; and test (count (commandline -opc)) -eq 2" -a "(__agent_existing_workspaces)"
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

  if [[ "${1:-}" == "codex" || "${1:-}" == "claude" || "${1:-}" == "fish" ]]; then
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

  if [[ "${1:-}" == "switch" ]]; then
    local workspace_dir
    workspace_dir="$("$script" switch-target "${@:2}")" || return $?
    cd "$workspace_dir" || return $?
    return 0
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
    COMPREPLY=( $(compgen -W "codex claude fish switch cleanup status help" -- "$cur") )
    return 0
  fi

  if [[ $COMP_CWORD -eq 2 && ( "$cmd" == "codex" || "$cmd" == "claude" || "$cmd" == "fish" || "$cmd" == "switch" ) ]]; then
    if command -v jj >/dev/null 2>&1; then
      local workspaces
      workspaces="$(jj workspace list --template 'name ++ "\n"' 2>/dev/null)"
      COMPREPLY=( $(compgen -W "$workspaces" -- "$cur") )
    fi
    return 0
  fi

  if [[ "$cmd" == "status" ]]; then
    COMPREPLY=( $(compgen -W "--compact --no-color" -- "$cur") )
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

  if [[ "${1:-}" == "codex" || "${1:-}" == "claude" || "${1:-}" == "fish" ]]; then
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

  if [[ "${1:-}" == "switch" ]]; then
    local workspace_dir
    workspace_dir="$("$script" switch-target "${@:2}")" || return $?
    cd "$workspace_dir" || return $?
    return 0
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
    'fish:Create workspace and launch Fish shell'
    'switch:Switch to existing workspace'
    'cleanup:Forget and delete current managed workspace'
    'status:Show JJ workspace status'
    'help:Show help'
  )

  if (( CURRENT == 2 )); then
    _describe -t commands 'agent commands' subcommands
    return
  fi

  if [[ "${words[2]}" == "codex" || "${words[2]}" == "claude" || "${words[2]}" == "fish" || "${words[2]}" == "switch" ]]; then
    if (( CURRENT == 3 )); then
      if (( $+commands[jj] )); then
        workspaces=("${(@f)$(jj workspace list --template 'name ++ "\n"' 2>/dev/null)}")
        compadd -a workspaces
      fi
    fi
    return
  fi

  if [[ "${words[2]}" == "status" ]]; then
    compadd -- --compact --no-color
    return
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
    switch-target)
      if [[ $# -gt 2 ]]; then
        print_error "'switch-target' accepts at most one workspace name."
      fi
      resolve_switch_target "${2:-}"
      ;;
    switch)
      if [[ $# -gt 2 ]]; then
        print_error "'switch' accepts at most one workspace name."
      fi
      switch_workspace "${2:-}"
      ;;
    help|-h|--help)
      print_help
      ;;
    status)
      run_status "${@:2}"
      ;;
    cleanup)
      if [[ $# -ne 1 ]]; then
        print_error "'cleanup' does not take extra arguments."
      fi
      cleanup_workspace
      ;;
    codex|claude|fish)
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
