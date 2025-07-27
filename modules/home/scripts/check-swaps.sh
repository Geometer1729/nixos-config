#!/usr/bin/env bash

# Hourly cron job to check for vim swap files and notify

set -euo pipefail

SWAP_DIR="${XDG_DATA_HOME:-$HOME/.local/state}/nvim/swap"

find_swap_files() {
    find "$SWAP_DIR" -name "*.swp" -o -name "*.swo" -o -name "*.swn" 2>/dev/null || true
    find . -name ".*.swp" -o -name ".*.swo" -o -name ".*.swn" 2>/dev/null || true
}

main() {
    local swap_files
    swap_files=$(find_swap_files)

    if [[ -n "$swap_files" ]]; then
        local count
        count=$(echo "$swap_files" | wc -l)
        notify-send "Vim Swap Files" "Found $count swap file(s). Run 'recover-swaps' to handle them." -u normal -i text-editor
    fi
}

main "$@"
