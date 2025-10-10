#!/usr/bin/env bash

set -euo pipefail

# If running from dmenu, launch in terminal
if [[ "${TERM:-}" == "dumb" ]] || [[ -z "${TERM:-}" ]]; then
    exec alacritty -e "$0" "$@"
fi

SWAP_DIR="${XDG_DATA_HOME:-$HOME/.local/state}/nvim/swap"
TEMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

find_swap_files() {
    find "$SWAP_DIR" -name "*.s*" 2>/dev/null || true
}

decode_swap_filename() {
    local swap_file="$1"
    local basename_swap
    local encoded_path
    local decoded_path

    basename_swap=$(basename "$swap_file")

    # Remove trailing .s* extension (any swap file extension starting with .s)
    if [[ "$basename_swap" == *.s* ]]; then
        encoded_path="${basename_swap%%.s*}"
    else
        encoded_path="$basename_swap"
    fi

    # Decode % encoding back to / for directory separators
    decoded_path="${encoded_path//%/\/}"

    echo "$decoded_path"
}


main() {
    local swap_files
    #local scratch_files=()
    #local scratch_counter=1

    swap_files=$(find_swap_files)

    if [[ -z "$swap_files" ]]; then
        echo "No swap files found"
        exit 0
    fi

    echo "Found swap files:"
    echo "$swap_files"
    echo

    while IFS= read -r swap_file; do
        [[ -z "$swap_file" ]] && continue

        local original_file
        original_file=$(decode_swap_filename "$swap_file")

        echo "$original_file" "$swap_file"
        if [ -f "$original_file" ]; then
          vim "$original_file"
        else
          vim -r "$swap_file"
        fi
        mv "$swap_file" "/tmp/$(basename "$swap_file")"
        echo "---"
    done <<< "$swap_files"
}

main "$@"
