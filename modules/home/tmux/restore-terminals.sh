#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux"
manifest="$state_dir/terminals.json"
restore_marker="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/tmux-resurrected"
resurrect_last="$HOME/.tmux/resurrect/last"

save() {
  local clients windows entries client_pid session pid workspace

  windows=$(hyprctl clients -j 2>/dev/null) || return 0
  clients=$(tmux list-clients -F '#{client_pid}	#{client_session}' 2>/dev/null) || clients=""
  entries='[]'

  while IFS=$'\t' read -r client_pid session; do
    [ -n "$client_pid" ] || continue
    pid=$client_pid
    workspace=$(jq -r --arg title "tmux:$session" '
      [
        .[]
        | select(.title == $title)
        | select(.workspace.id > 0)
        | select(.class | ascii_downcase | contains("ghostty"))
        | .workspace.id
      ]
      | unique
      | if length == 1 then .[0] else empty end
    ' <<<"$windows")

    while [ -z "$workspace" ] && [ "$pid" -gt 1 ]; do
      workspace=$(jq -r --argjson pid "$pid" '
        [
          .[]
          | select(.pid == $pid)
          | select(.workspace.id > 0)
          | select(.class | ascii_downcase | contains("ghostty"))
          | .workspace.id
        ]
        | unique
        | if length == 1 then .[0] else empty end
      ' <<<"$windows")
      [ -z "$workspace" ] || break
      pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
      [ -n "$pid" ] || break
    done

    if [ -n "$workspace" ]; then
      entries=$(jq --arg session "$session" --argjson workspace "$workspace" \
        '. + [{ session: $session, workspace: $workspace }]' <<<"$entries")
    fi
  done <<<"$clients"

  jq -e 'length > 0' <<<"$entries" >/dev/null || return 0
  mkdir -p "$state_dir"
  printf '%s\n' "$entries" >"$manifest.tmp"
  mv "$manifest.tmp" "$manifest"
}

restore() {
  local session workspace job failed=false
  local -a sessions=() jobs=()

  [ -s "$manifest" ] || return 0

  for _ in $(seq 1 100); do
    hyprctl monitors -j >/dev/null 2>&1 && break
    sleep 0.1
  done
  hyprctl monitors -j >/dev/null 2>&1 || return 0

  # Only wait for sessions tmux-resurrect will recreate: the manifest can list
  # a session that ended before the final snapshot.
  while IFS= read -r session; do
    [[ "$session" =~ [[:space:]] ]] && continue
    if tmux has-session -t "=$session" 2>/dev/null || in_snapshot "$session"; then
      sessions+=("$session")
    else
      echo "Skipping $session: not in the tmux-resurrect snapshot" >&2
    fi
  done < <(jq -r '.[].session' "$manifest")

  if ! sessions_ready "${sessions[@]}"; then
    if ! tmux has-session 2>/dev/null; then
      rm -f "$restore_marker"
      # Start the server in its own scope: left in this unit's cgroup, it would
      # be killed whenever the unit stops or restarts. The tmux-spawn- prefix
      # applies the drop-in that keeps it alive for the logout save.
      systemd-run --user --scope --collect --quiet --unit="tmux-spawn-server-$$" \
        tmux new-session -d -s 0 2>/dev/null || tmux has-session -t '=0'
    fi

    for _ in $(seq 1 200); do
      [ -e "$restore_marker" ] && break
      sleep 0.1
    done

    if [ ! -e "$restore_marker" ]; then
      echo "Timed out waiting for tmux-resurrect to finish" >&2
      return 1
    fi
  fi

  for _ in $(seq 1 200); do
    sessions_ready "${sessions[@]}" && break
    sleep 0.1
  done

  # Attach whatever was restored rather than leaving every window closed.
  if ! sessions_ready "${sessions[@]}"; then
    echo "Timed out waiting for tmux-resurrect to restore terminal sessions" >&2
    failed=true
  fi

  # Open every terminal at once, so one slow to start doesn't hold up the rest.
  while IFS=$'\t' read -r session workspace; do
    [[ "$session" =~ [[:space:]] ]] && continue
    tmux has-session -t "=$session" 2>/dev/null || continue
    attached "$session" && continue
    open_terminal "$session" "$workspace" &
    jobs+=("$!")
  done < <(jq -r '.[] | [.session, .workspace] | @tsv' "$manifest")

  for job in "${jobs[@]}"; do
    wait "$job" || failed=true
  done

  if $failed; then
    return 1
  fi
}

# Opens a terminal attached to the session on the workspace, failing if none attaches.
open_terminal() {
  local session=$1 workspace=$2 command attempt result tick

  command="$(command -v ghostty) -e $(command -v tmux) attach-session -t =$session"
  # A dispatch can succeed without a terminal ever attaching (seen at boot),
  # so confirm the client and retry rather than trusting hyprctl's reply.
  # A terminal can also take over 10s to attach at boot, so only relaunch
  # once the previous one has exited; relaunching early opened two.
  for attempt in 1 2 3; do
    result=$(hyprctl dispatch "hl.dsp.exec_cmd([==[$command]==], { workspace = \"$workspace silent\" })" 2>&1) || true
    for tick in $(seq 1 300); do
      attached "$session" && break
      # Give Hyprland a moment to spawn it before treating it as gone.
      ((tick > 20)) && ! launching "$session" && break
      sleep 0.1
    done
    if attached "$session"; then
      echo "Attached $session on workspace $workspace (attempt $attempt)"
      return 0
    fi
    if launching "$session"; then
      echo "Terminal for $session still had not attached after 30s; not relaunching" >&2
      return 1
    fi
    echo "No terminal attached to $session after attempt $attempt; hyprctl: $result" >&2
  done
  return 1
}

sessions_ready() {
  local session
  for session in "$@"; do
    tmux has-session -t "=$session" 2>/dev/null || return 1
  done
}

in_snapshot() {
  awk -F'\t' -v session="$1" '
    $1 == "pane" && $2 == session { found = 1; exit }
    END { exit !found }
  ' "$resurrect_last" 2>/dev/null
}

attached() {
  tmux list-clients -F '#{client_session}' 2>/dev/null | grep -Fxq "$1"
}

# Whether a terminal (or its tmux client) launched for this session is running.
launching() {
  ps -eo args= | awk -v suffix="attach-session -t =$1" '
    substr($0, length($0) - length(suffix) + 1) == suffix { found = 1; exit }
    END { exit !found }
  '
}

case "${1:-restore}" in
  save) save ;;
  restore) restore ;;
  *)
    echo "Usage: restore-terminals [save|restore]" >&2
    exit 2
    ;;
esac
