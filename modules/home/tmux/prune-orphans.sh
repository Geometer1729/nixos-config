#!/usr/bin/env bash
# Kill detached, numbered sessions that are a single idle shell pane in $HOME.
set -euo pipefail

dry_run=false
[ "${1:-}" = "--dry-run" ] && dry_run=true

while IFS=$'\t' read -r session attached; do
  [[ "$session" =~ ^[0-9]+$ && "$attached" = 0 ]] || continue
  panes=$(tmux list-panes -s -t "=$session" -F '#{pane_current_command} #{pane_current_path}')
  # Exactly one pane, running an idle shell in $HOME.
  [[ "$panes" =~ ^(zsh|bash|sh)\ "$HOME"$ ]] || continue

  if $dry_run; then
    echo "would prune $session"
  else
    tmux kill-session -t "=$session"
    echo "pruned $session"
  fi
done < <(tmux list-sessions -F '#{session_name}	#{session_attached}')
