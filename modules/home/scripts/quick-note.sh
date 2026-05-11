#!/usr/bin/env bash

notes_dir="${VIMWIKI_QUICK_NOTES_DIR:-$HOME/Documents/vw/notes}"
mkdir -p "$notes_dir"

if [ "$#" -gt 0 ]; then
  title="$*"
else
  printf "Note title (optional): "
  read -r title
fi

if [ -z "$title" ]; then
  title="Quick note"
fi

slug="${title,,}"
slug="${slug//[^a-z0-9]/-}"
if [ -z "$slug" ]; then
  slug="note"
fi

note_file="$notes_dir/$slug.md"
if [ -e "$note_file" ]; then
  note_file="$notes_dir/$slug-$(date '+%Y-%m-%d-%H%M%S').md"
fi

if ! [ -e "$note_file" ]; then
  {
    printf '# %s\n\n' "$title"
  } > "$note_file"
fi

vim "$note_file" +

if [ "${HIDE_AFTER_REBUILD:-false}" = "true" ]; then
  scratchPad vim hide
fi
