#!/usr/bin/env bash
# Open a Ghostty window for every tmux session with no attached client.
set -euo pipefail

ghostty=$(command -v ghostty)
tmux=$(command -v tmux)

while IFS=$'\t' read -r session attached; do
  [ "$attached" = 0 ] || continue
  target=$(printf '%q' "=$session")
  hyprctl dispatch exec "$ghostty --title=$(printf '%q' "tmux:$session") -e $tmux attach-session -t $target" >/dev/null
done < <(tmux list-sessions -F '#{session_name}	#{session_attached}' 2>/dev/null)
