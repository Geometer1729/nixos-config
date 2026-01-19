#!/usr/bin/env bash

# Wait for Hyprland to be ready
while ! hyprctl activeworkspace -j >/dev/null 2>&1; do
  sleep 0.2
done
# Optional: tiny extra settle time
sleep 0.5

# Check for --group flag to wait for a group on a workspace
if [[ "${1:-}" == "--group" ]]; then
  workspace="${2:?--group requires a workspace number}"
  # Wait for a grouped window to exist on the target workspace
  while ! hyprctl clients -j | jq -e ".[] | select(.workspace.id == $workspace and (.grouped | length > 0))" >/dev/null 2>&1; do
    sleep 0.2
  done
fi
