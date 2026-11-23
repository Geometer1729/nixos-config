# Resolve the supplied pane, or the calling TUI's pane, to its terminal window.
# OpenCode's wrapper puts nixpkgs' libstdc++ on LD_LIBRARY_PATH for its embedded
# addons, and it is older than the one hyprctl is built against.
unset LD_LIBRARY_PATH
pane="${2:-${TMUX_PANE:?OpenCode notification focus requires tmux}}"
session=$(tmux display-message -p -t "$pane" '#{session_name}')
# The OpenCode server and tmux outlive Hyprland restarts, so their
# HYPRLAND_INSTANCE_SIGNATURE can name a dead compositor. Use the running one.
# Ghostty serves several windows from one process; match tmux's set-titles string
# instead, or the bare name scratchpads are launched with.
window=$(hyprctl -i 0 clients -j | jq -ec --arg session "$session" '
  [.[] | select((.title == "tmux:" + $session or .title == $session) and (.class | ascii_downcase | contains("ghostty")))]
  | min_by(.focusHistoryID)')

if [[ "${1-}" == "--workspace" ]]; then
  jq -r '.workspace.name' <<<"$window"
  exit 0
fi

tmux select-window -t "$pane"
tmux select-pane -t "$pane"
address=$(jq -r '.address' <<<"$window")
hyprctl -i 0 dispatch "hl.dsp.focus({ window = \"address:$address\" })"
