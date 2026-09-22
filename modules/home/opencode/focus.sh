# Resolve the supplied pane, or the calling TUI's pane, to its terminal window.
pane="${2:-${TMUX_PANE:?OpenCode notification focus requires tmux}}"
session=$(tmux display-message -p -t "$pane" '#{session_id}')
client=$(tmux list-clients -t "$session" -F '#{client_pid}' | head -n 1)
terminal=$(ps -o ppid= -p "$client" | tr -d ' ')
window=$(hyprctl clients -j | jq -ec --argjson pid "$terminal" 'first(.[] | select(.pid == $pid))')

if [[ "${1-}" == "--workspace" ]]; then
  jq -r '.workspace.name' <<<"$window"
  exit 0
fi

tmux select-window -t "$pane"
tmux select-pane -t "$pane"
hyprctl dispatch focuswindow "address:$(jq -r '.address' <<<"$window")"
