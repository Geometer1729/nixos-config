#!/usr/bin/env bash

# Script to handle vim swap files with lazygit integration
# Finds swap files, shows diffs, and lets you choose which changes to keep

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
    find "$SWAP_DIR" -name "*.swp" -o -name "*.swo" -o -name "*.swn" 2>/dev/null || true
    find . -name ".*.swp" -o -name ".*.swo" -o -name ".*.swn" 2>/dev/null || true
}

decode_swap_filename() {
    local swap_file="$1"
    local basename_swap
    local encoded_path
    local decoded_path

    basename_swap=$(basename "$swap_file")

    # Remove trailing .swp/.swo/.swn
    if [[ "$basename_swap" == *.swp ]]; then
        encoded_path="${basename_swap%.swp}"
    elif [[ "$basename_swap" == *.swo ]]; then
        encoded_path="${basename_swap%.swo}"
    elif [[ "$basename_swap" == *.swn ]]; then
        encoded_path="${basename_swap%.swn}"
    else
        encoded_path="$basename_swap"
    fi

    # Decode % encoding back to / for directory separators
    decoded_path="${encoded_path//%/\/}"

    echo "$decoded_path"
}

recover_swap() {
    local swap_file="$1"
    local original_file

    # Decode the original filename from the swap file
    original_file=$(decode_swap_filename "$swap_file")

    if [[ ! -f "$original_file" ]]; then
        echo "Warning: Cannot find original file $original_file for $swap_file"
        return 1
    fi

    echo "Processing swap file: $swap_file"
    echo "Original file: $original_file"

    # Create a temporary git repo for safe diff review
    local temp_repo="$TEMP_DIR/git_repo"
    mkdir -p "$temp_repo"
    cd "$temp_repo"

    # Initialize git repo
    git init -q
    git config user.email "swap-recovery@localhost"
    git config user.name "Swap Recovery"

    # Copy original file to temp repo
    local filename
    filename=$(basename "$original_file")
    cp "$original_file" "$filename"
    git add "$filename"
    git commit -q -m "Original file"

    # Recover from swap file to a temporary location (avoiding vim hang)
    local recovered_file="$TEMP_DIR/recovered_content"
    if ! vim -r "$swap_file" -c "write $recovered_file" -c "quit!" < /dev/null &>/dev/null; then
        echo "Failed to recover from $swap_file"
        return 1
    fi

    # Check if there are differences
    if diff -q "$original_file" "$recovered_file" >/dev/null 2>&1; then
        echo "No differences found, removing swap file"
        rm -f "$swap_file"
        return 0
    fi

    # Apply recovered changes to temp repo
    cp "$recovered_file" "$filename"
    git add "$filename"

    echo "Differences found. Opening lazygit to review changes..."
    echo "Use lazygit to stage the changes you want to keep, then exit."
    echo "Press Enter to continue..."
    read -r

    # Launch lazygit for review
    lazygit

    # Commit staged changes
    if git diff --cached --quiet; then
        echo "No changes were staged. Keeping original file unchanged."
        rm -f "$swap_file"
        return 0
    fi

    git commit -q -m "Recovered changes from swap file"

    # Show the diff that will be applied
    echo "==================== DIFF PREVIEW ===================="
    git show --no-pager
    echo "========================================================"

    echo "Apply this diff to the original file?"
    echo "1) Yes, apply the diff"
    echo "2) No, keep original file unchanged"
    echo "3) Keep swap file for later"
    read -r -p "Choice (1-3): " choice

    case $choice in
        1)
            # Apply the diff to original file
            git show --format="" > "$TEMP_DIR/changes.patch"
            cd "$(dirname "$original_file")"
            if patch -p1 < "$TEMP_DIR/changes.patch"; then
                echo "Successfully applied changes to $original_file"
                rm -f "$swap_file"
            else
                echo "Failed to apply patch. Keeping swap file."
            fi
            ;;
        2)
            echo "Keeping original file unchanged"
            rm -f "$swap_file"
            ;;
        3)
            echo "Keeping swap file for later"
            ;;
        *)
            echo "Invalid choice, keeping swap file"
            ;;
    esac
}

handle_missing_file() {
    local swap_file="$1"
    local original_file="$2"
    local parent_dir
    parent_dir=$(dirname "$original_file")

    # Recover content to temp file for preview (avoiding vim hang)
    local temp_file="$TEMP_DIR/preview"
    if ! vim -r "$swap_file" -c "write $temp_file" -c "quit!" < /dev/null &>/dev/null; then
        echo "Failed to recover from $swap_file"
        return 1
    fi

    if [[ -d "$parent_dir" ]]; then
        # Parent directory exists, offer to create the file
        echo "Original file doesn't exist but parent directory does:"
        echo "File: $original_file"
        echo "Content preview:"
        echo "===================="
        head -20 "$temp_file"
        echo "===================="

        echo "What would you like to do?"
        echo "1) Create the file with this content"
        echo "2) Save to scratch file and continue"
        echo "3) Skip this swap file"
        read -r -p "Choice (1-3): " choice

        case $choice in
            1)
                cp "$temp_file" "$original_file"
                rm -f "$swap_file"
                echo "Created $original_file, deleted swap file"
                ;;
            2)
                local scratch_file="/tmp/scratch-${scratch_counter}"
                cp "$temp_file" "$scratch_file"
                scratch_files+=("$scratch_file")
                rm -f "$swap_file"
                echo "Saved to $scratch_file, deleted swap file"
                ((scratch_counter++))
                ;;
            3)
                echo "Skipping swap file"
                ;;
            *)
                echo "Invalid choice, skipping"
                ;;
        esac
    else
        # Parent directory doesn't exist, save to scratch file
        local scratch_file="/tmp/scratch-${scratch_counter}"
        echo "Processing orphaned swap file: $swap_file"
        echo "Original path: $original_file (parent directory doesn't exist)"
        echo "Saving to: $scratch_file"

        cp "$temp_file" "$scratch_file"
        scratch_files+=("$scratch_file")
        rm -f "$swap_file"
        echo "Recovered to $scratch_file, deleted swap file"
        ((scratch_counter++))
    fi
}

main() {
    local swap_files
    local scratch_files=()
    local scratch_counter=1

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

        if [[ -f "$original_file" ]]; then
            # Regular file exists, process normally
            recover_swap "$swap_file"
        else
            # File doesn't exist, handle appropriately
            handle_missing_file "$swap_file" "$original_file"
        fi
        echo "---"
    done <<< "$swap_files"

    # Open all scratch files in vim tabs if any were created
    if [[ ${#scratch_files[@]} -gt 0 ]]; then
        echo "Opening ${#scratch_files[@]} scratch files in vim..."
        nvim -p "${scratch_files[@]}"
    fi
}

main "$@"
