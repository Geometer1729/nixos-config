#!/usr/bin/env bash
# Smart tab behavior: cycle within group if in a group, otherwise focus next window

# Get the active window info and check if it's grouped
if hyprctl activewindow -j | jq -e '.grouped | any' > /dev/null 2>&1; then
  # Window is in a group, cycle within group
  hyprctl dispatch changegroupactive f
else
  # Window is not in a group, focus next window
  hyprctl dispatch cyclenext
fi
