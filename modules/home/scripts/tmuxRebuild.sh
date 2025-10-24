#!/usr/bin/env bash

# Check if we're already in the sp scratchpad - if so, don't hide after rebuild
hide_after=$(hyprctl activewindow -j 2>/dev/null | jq -r '.title' | grep -q "^sp$" && echo "false" || echo "true")

scratchPad sp show
tmux kill-window -t sp:rebuild 2>/dev/null || true

tmux new-window -e HIDE_SP_AFTER_REBUILD="$hide_after" -t sp -n rebuild rebuild \
  || (sleep 0.5 && tmux new-window -e HIDE_SP_AFTER_REBUILD="$hide_after" -t sp -n rebuild rebuild) \
  || (sleep 1.0 && tmux new-window -e HIDE_SP_AFTER_REBUILD="$hide_after" -t sp -n rebuild rebuild)
