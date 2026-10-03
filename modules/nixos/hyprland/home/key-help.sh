#!/usr/bin/env bash
set -euo pipefail

# List how to reach key help for each layer under the focused window: Hyprland,
# the app, tmux, and the program in tmux's active pane. Selecting a row runs it.
# KEY_HELP_PROGRAMS is the JSON form of the keyHelp option.

window=$(hyprctl activewindow -j)
class=$(jq -r '.class // ""' <<< "$window")
title=$(jq -r '.title // ""' <<< "$window")
export KEY_HELP_WINDOW KEY_HELP_PANE='' KEY_HELP_CLIENT=''
KEY_HELP_WINDOW=$(jq -r '.address // ""' <<< "$window")

in_tmux=false
process=''
if [[ $class == com.mitchellh.ghostty ]]; then
  # tmux titles terminals tmux:<session>; scratchpads keep their session name.
  session=${title#tmux:}
  if tmux has-session -t "=$session" 2>/dev/null; then
    in_tmux=true
    read -r KEY_HELP_PANE pane_pid < <(tmux display-message -p -t "=$session:" '#{pane_id} #{pane_pid}')
    KEY_HELP_CLIENT=$(tmux list-clients -t "=$session" -F '#{client_name}' | head -n 1)
    # pane_current_command names interpreters (python3.13) rather than programs.
    foreground=$(ps -o tpgid= -p "$pane_pid" | tr -d ' ')
    process=$(ps -o args= -p "$foreground" || true)
  fi
fi

rows=$(jq -c --arg class "$class" --arg title "$title" --arg process "$process" \
  --argjson tmux "$in_tmux" '
  def matches($pattern; $value): $pattern == null or ($value | test($pattern));
  [to_entries | map(.value + {name: .key}) | sort_by(.order, .name)[] |
   select(matches(.match.class; $class) and matches(.match.title; $title)
     and (.match.process == null or ($tmux and matches(.match.process; $process)))) |
   .label as $label | .binds[] | . + {label: $label}]
' "$KEY_HELP_PROGRAMS")

index=$(jq -r '
  def pad($width): . + " " * ([1, $width - length] | max);
  .[] | (.label | pad(12)) + (.key | pad(16)) + .description
' <<< "$rows" | rofi -dmenu -i -no-custom -format i -p Help) || exit 0

row=$(jq -c ".[$index]" <<< "$rows")
notify-send "Next time: $(jq -r '.key' <<< "$row")" \
  "$(jq -r '"\(.label): \(.description)"' <<< "$row")"

if jq -e '.keys != null' <<< "$row" >/dev/null; then
  mapfile -t keys < <(jq -r '.keys[]' <<< "$row")
  tmux send-keys -t "$KEY_HELP_PANE" "${keys[@]}"
elif command=$(jq -er '.command' <<< "$row"); then
  sh -c "$command"
fi
