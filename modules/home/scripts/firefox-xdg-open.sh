#!/usr/bin/env bash
# Wrapper for xdg-open to open URLs in Firefox and route to appropriate profile

url="${1:-}"

# Determine which Firefox profile and workspace to use based on URL
if [[ "$url" =~ youtube\.com|youtu\.be ]]; then
    profile="youtube"
    workspace=1
elif [[ "$url" =~ linear\.app ]]; then
    profile="work"
    workspace=18
elif [[ "$url" =~ aonprd\.com ]]; then
    profile="ttrpg"
    workspace=20
else
    profile="default"
    workspace=2
fi

# Switch to the appropriate workspace
hyprctl dispatch workspace "$workspace"

# Open URL in the appropriate Firefox profile
firefox -P "$profile" --new-tab "$url"
