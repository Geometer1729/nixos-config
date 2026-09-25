#!/usr/bin/env bash
# Type the clipboard as keystrokes, for fields that block or mangle paste.

# Typing is slow and cannot be undone, so refuse anything this long.
max_chars=2000

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# Keep the text in a file: shell variables lose trailing newlines.
if ! wl-paste --no-newline --type text > "$workdir/text" 2>/dev/null; then
  notify-send --urgency=critical "Force paste" "Clipboard does not contain text"
  exit 1
fi

if [ ! -s "$workdir/text" ]; then
  notify-send "Force paste" "Clipboard is empty"
  exit 1
fi

chars="$(wc -m < "$workdir/text")"
if [ "$chars" -gt "$max_chars" ]; then
  notify-send --urgency=critical "Force paste" "Refusing to type $chars characters (limit $max_chars)"
  exit 1
fi

# Let the hotkey's modifiers be released so they don't combine with typed keys.
sleep 0.2
wtype - < "$workdir/text"
