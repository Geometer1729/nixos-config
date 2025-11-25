#!/usr/bin/env bash
# Wrapper for xdg-open to open URLs in Firefox and switch to workspace 2

url="${1:-}"

# Switch to workspace 2 (where default Firefox lives)
hyprctl dispatch workspace 2

# Open URL in Firefox default profile
firefox -P default "$url"
