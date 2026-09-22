# Run in the TUI's environment: its tmux pane identifies the containing terminal.
pane="${TMUX_PANE:?OpenCode notification focus requires tmux}"
session=$(tmux display-message -p -t "$pane" '#{session_id}')
client=$(tmux list-clients -t "$session" -F '#{client_pid}' | head -n 1)
terminal=$(ps -o ppid= -p "$client" | tr -d ' ')
address=$(hyprctl clients -j | jq -er --argjson pid "$terminal" 'first(.[] | select(.pid == $pid)).address')

tmux select-window -t "$pane"
tmux select-pane -t "$pane"
hyprctl dispatch focuswindow "address:$address"
