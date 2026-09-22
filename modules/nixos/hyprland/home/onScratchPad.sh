#!/usr/bin/env bash

# Usage: onScratchPad [--hide-after] <scratchpad_name> <window_name> <command>
#
# Creates or switches to a tmux window in a scratchpad session.
# --hide-after: Set HIDE_AFTER_REBUILD env var based on whether already in scratchpad
# Example: onScratchPad --hide-after sp rebuild rebuild

HIDE_AFTER_FLAG=false
if [ "$1" = "--hide-after" ]; then
  HIDE_AFTER_FLAG=true
  shift
fi

SCRATCHPAD_NAME="$1"
WINDOW_NAME="$2"
COMMAND="$3"

if [ -z "$SCRATCHPAD_NAME" ] || [ -z "$WINDOW_NAME" ] || [ -z "$COMMAND" ]; then
  echo "Usage: onScratchPad [--hide-after] <scratchpad_name> <window_name> <command>"
  exit 1
fi

# Check if we're already in the scratchpad - if so, don't hide after command completes
if [ "$HIDE_AFTER_FLAG" = true ]; then
  hide_after=$(hyprctl activewindow -j 2>/dev/null | jq -r '.title' | grep -q "^$SCRATCHPAD_NAME$" && echo "false" || echo "true")
  EXTRA_ENV=(-e "HIDE_AFTER_REBUILD=$hide_after")
else
  EXTRA_ENV=()
fi

scratchPad "$SCRATCHPAD_NAME" show
tmux kill-window -t "$SCRATCHPAD_NAME:$WINDOW_NAME" 2>/dev/null || true

tmux new-window "${EXTRA_ENV[@]}" -t "$SCRATCHPAD_NAME" -n "$WINDOW_NAME" "$COMMAND" \
  || (sleep 0.5 && tmux new-window "${EXTRA_ENV[@]}" -t "$SCRATCHPAD_NAME" -n "$WINDOW_NAME" "$COMMAND") \
  || (sleep 1.0 && tmux new-window "${EXTRA_ENV[@]}" -t "$SCRATCHPAD_NAME" -n "$WINDOW_NAME" "$COMMAND")
