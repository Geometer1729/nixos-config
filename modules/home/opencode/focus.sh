# Resolve the supplied pane, or the calling TUI's pane, to its terminal window.
pane="${2:-${TMUX_PANE:?OpenCode notification focus requires tmux}}"
session=$(tmux display-message -p -t "$pane" '#{session_name}')
# Ghostty serves several windows from one process; match tmux's set-titles string
# instead, or the bare name scratchpads are launched with.
window=$(hyprctl clients -j | jq -ec --arg session "$session" '
  [.[] | select((.title == "tmux:" + $session or .title == $session) and (.class | ascii_downcase | contains("ghostty")))]
  | min_by(.focusHistoryID)')

if [[ "${1-}" == "--workspace" ]]; then
  jq -r '.workspace.name' <<<"$window"
  exit 0
fi

tmux select-window -t "$pane"
tmux select-pane -t "$pane"
hyprctl dispatch focuswindow "address:$(jq -r '.address' <<<"$window")"
