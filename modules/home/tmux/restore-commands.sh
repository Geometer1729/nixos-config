#!/usr/bin/env bash
# Stand-in for tmux-resurrect's process restore, which types each saved
# command into a new pane before its shell is ready; slow shell startup (a
# cold direnv `use flake`) can swallow those keys. Instead, tag each restored
# pane with its command and let zsh run it at the first prompt
# (modules/home/zsh/tmuxRestore.zsh).
#
#   restore-commands pre   resurrect pre-restore-all hook
#   restore-commands post  resurrect post-restore-all hook
set -euo pipefail

marker="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/tmux-resurrected"

# Same matching as resurrect: `~pattern` matches anywhere in the full command,
# a bare word must be the program; `->command` replaces the saved command.
matches() {
  local command=$1 match=${2%%->*}
  if [[ "$match" == "~"* ]]; then
    [[ "$command" =~ (${match#\~}) ]]
  else
    [[ "$command" =~ (^${match} ) || "$command" =~ (^${match}$) ]]
  fi
}

pre() {
  # Panes that exist before the restore are left alone, as resurrect does.
  tmux set-option -g @restore-existing-panes \
    " $(tmux list-panes -a -F '#{pane_id}' | tr '\n' ' ')"
  tmux set-option -g @restoring "$(date +%s)"
}

post() {
  local dir existing session window pane command id entry
  dir=$(tmux show-options -gqv @resurrect-dir)
  dir=${dir:-$HOME/.tmux/resurrect}
  dir=${dir//\$HOME/$HOME}
  dir=${dir/#\~/$HOME}
  existing=$(tmux show-options -gqv @restore-existing-panes)

  local -a entries
  eval "entries=($(tmux show-options -gqv @restore-processes))"

  # Exact lookup; `-t` targets can resolve a missing session to another pane.
  local -A panes
  while IFS=$'\t' read -r session window pane id; do
    panes["$session"$'\t'"$window"$'\t'"$pane"]=$id
  done < <(tmux list-panes -a -F '#{session_name}	#{window_index}	#{pane_index}	#{pane_id}')

  while IFS=$'\t' read -r session window pane command; do
    command=${command#:}
    [ -n "$command" ] || continue
    id=${panes["$session"$'\t'"$window"$'\t'"$pane"]:-}
    [ -n "$id" ] || continue
    [[ "$existing" == *" $id "* ]] && continue
    # Restored panes keep their saved session; see the direnv tmux renaming.
    tmux set-option -p -t "$id" @restored 1
    for entry in "${entries[@]}"; do
      if matches "$command" "$entry"; then
        [[ "$entry" == *"->"* ]] && command=${entry#*->}
        tmux set-option -p -t "$id" @restore-command "$command"
        break
      fi
    done
  done < <(awk -F'\t' -v OFS='\t' '$1 == "pane" { print $2, $3, $6, $11 }' "$dir/last")

  tmux set-option -gu @restoring
  tmux set-option -gu @restore-existing-panes
  touch "$marker"
}

case "${1:-}" in
  pre) pre ;;
  post) post ;;
  *)
    echo "Usage: restore-commands pre|post" >&2
    exit 2
    ;;
esac
