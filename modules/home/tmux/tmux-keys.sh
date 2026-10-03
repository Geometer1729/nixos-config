#!/usr/bin/env bash
set -euo pipefail

# Search prefix-table bindings (and noted root bindings) in a popup on CLIENT,
# then press the chosen one. `tmux-keys --pick FILE` is the popup side.

if [[ ${1:-} == --pick ]]; then
  # With -a, the root table's mouse and plugin bindings have no notes and break
  # tmux's column alignment, so only noted root bindings are listed.
  {
    tmux list-keys -N -a -P '' -T prefix | sed 's/^/prefix\t/'
    tmux list-keys -N -P '' -T root | sed 's/^/root\t/'
  } | awk -F '\t' -v prefix="$(tmux show-options -gv prefix)" '{
      key = $2; sub(/ .*/, "", key)
      note = $2; sub(/^[^ ]+ +/, "", note); gsub(/\/nix\/store\/[^ ]*\//, "", note)
      shown = ($1 == "prefix" ? prefix " " : "") key
      printf "%s\t%s\t%-14s %s\t%s\n", $1, key, shown, note, shown
    }' | fzf --delimiter='\t' --with-nth=3 --prompt='tmux keys> ' > "$2" || true
  exit 0
fi

client=${1:-$(tmux display-message -p '#{client_name}')}
choice=$(mktemp)
trap 'rm -f "$choice"' EXIT

tmux display-popup -c "$client" -w 80% -h 80% -T ' tmux keys ' -E \
  "$(printf '%q ' "$0" --pick "$choice")"

IFS=$'\t' read -r table key _ shown < "$choice" || exit 0
tmux display-message -c "$client" -d 3000 "Next time: $shown"
if [[ $table == prefix ]]; then
  tmux send-keys -K -c "$client" "$(tmux show-options -gv prefix)" "$key"
else
  tmux send-keys -K -c "$client" "$key"
fi
