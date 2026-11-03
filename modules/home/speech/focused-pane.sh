#!/usr/bin/env bash
# Print the tmux pane the focused window shows, if it is a Ghostty window titled
# after its tmux session (as opencode-focus assumes). Prints nothing otherwise.

window=$(hyprctl activewindow -j) || exit 0
jq -e '.class // "" | ascii_downcase | contains("ghostty")' <<< "$window" > /dev/null || exit 0
session=$(jq -r '.title' <<< "$window")
session=${session#tmux:}
tmux has-session -t "=$session" 2> /dev/null || exit 0
tmux display-message -p -t "=$session:" '#{pane_id}'
