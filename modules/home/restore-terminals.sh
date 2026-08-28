#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux"
manifest="$state_dir/terminals.json"
restore_marker="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/tmux-resurrected"

save() {
  local clients windows entries client_pid session pid workspace

  windows=$(hyprctl clients -j 2>/dev/null) || return 0
  clients=$(tmux list-clients -F '#{client_pid}	#{client_session}' 2>/dev/null) || clients=""
  entries='[]'

  while IFS=$'\t' read -r client_pid session; do
    [ -n "$client_pid" ] || continue
    pid=$client_pid
    workspace=""

    while [ "$pid" -gt 1 ]; do
      workspace=$(jq -r --argjson pid "$pid" '
        .[]
        | select(.pid == $pid)
        | select(.workspace.id > 0)
        | select(.class | ascii_downcase | contains("ghostty"))
        | .workspace.id
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

  mkdir -p "$state_dir"
  printf '%s\n' "$entries" >"$manifest.tmp"
  mv "$manifest.tmp" "$manifest"
}

restore() {
  local started_server=false session workspace command

  [ -s "$manifest" ] || return 0

  for _ in $(seq 1 100); do
    hyprctl monitors -j >/dev/null 2>&1 && break
    sleep 0.1
  done
  hyprctl monitors -j >/dev/null 2>&1 || return 0

  if ! tmux has-session 2>/dev/null; then
    rm -f "$restore_marker"
    tmux new-session -d -s 0
    started_server=true
  fi

  if $started_server; then
    for _ in $(seq 1 200); do
      [ -e "$restore_marker" ] && break
      sleep 0.1
    done
  fi

  while IFS=$'\t' read -r session workspace; do
    [[ "$session" =~ [[:space:]] ]] && continue
    tmux has-session -t "=$session" 2>/dev/null || continue
    if tmux list-clients -F '#{client_session}' 2>/dev/null | grep -Fxq "$session"; then
      continue
    fi

    command="$(command -v ghostty) --title=tmux:$session -e $(command -v tmux) attach-session -t =$session"
    hyprctl dispatch exec "[workspace $workspace silent] $command" >/dev/null
  done < <(jq -r '.[] | [.session, .workspace] | @tsv' "$manifest")
}

case "${1:-restore}" in
  save) save ;;
  restore) restore ;;
  *)
    echo "Usage: restore-terminals [save|restore]" >&2
    exit 2
    ;;
esac
