#!/usr/bin/env bash
# Push-to-talk dictation through Hex: `dictate start` on key press, `dictate stop` on release.
# The transcript goes where the press was, so focus can move on before it arrives:
# straight into the prompt of an OpenCode TUI in that tmux pane, otherwise pasted
# only if that window still has focus, and left on the clipboard if not.

state="$XDG_RUNTIME_DIR/dictation"
target="$state/target"

notify() {
  notify-send --app-name=Hex "$@"
}

# The focused window's address and, for a Ghostty window titled after its tmux
# session (as opencode-focus assumes), that session's active pane.
focused() {
  local window session pane=""
  window=$(hyprctl activewindow -j)
  if jq -e '.class // "" | ascii_downcase | contains("ghostty")' <<< "$window" > /dev/null; then
    session=$(jq -r '.title' <<< "$window")
    session=${session#tmux:}
    if tmux has-session -t "=$session" 2> /dev/null; then
      pane=$(tmux display-message -p -t "=$session:" '#{pane_id}')
    fi
  fi
  printf '%s %s\n' "$(jq -r '.address // ""' <<< "$window")" "$pane"
}

# Returns 2 when no OpenCode TUI listens in the pane, 1 when it could not take the text.
deliver() {
  # Must match socketPath in the OpenCode dictation plugin.
  local socket="$XDG_RUNTIME_DIR/opencode-dictation-${1#%}.sock" reply
  [[ -S "$socket" ]] || return 2
  # A killed TUI leaves its socket refusing connections, and pane IDs restart with tmux.
  reply=$(printf '%s' "$2" | socat -t 5 - "UNIX-CONNECT:$socket" 2> /dev/null) || return 2
  [[ "$reply" == ok ]]
}

paste() {
  local keys=()
  # wtype numbers its keymap from evdev code 1 in order of first use. Releasing
  # unused placeholders first puts V on KEY_V, so Hyprland's binds read it as V,
  # as Hex's own paste does.
  for i in {0..45}; do
    keys+=(-p "$(printf 'U%04X' $((0x2460 + i)))")
  done
  if jq -e '.paste_with_shift' "$HOME/.local/share/hex/settings.json" > /dev/null 2>&1; then
    keys+=(-M ctrl -M shift -k v -m shift -m ctrl)
  else
    keys+=(-M ctrl -k v -m ctrl)
  fi
  # GTK 3 skips the final keycode when looking up shortcuts.
  keys+=(-p VoidSymbol)
  wtype "${keys[@]}"
}

start() {
  mkdir -p "$state"
  rm -f "$target"
  local where errors
  where=$(focused)
  if ! errors=$(hex dictation start 2>&1 > /dev/null); then
    notify --urgency=critical "Dictation failed" "$errors"
    exit 1
  fi
  printf '%s\n' "$where" > "$target"
}

stop() {
  # A quick tap can release before start has recorded where it was.
  for _ in {1..40}; do
    [[ -f "$target" ]] && break
    sleep 0.05
  done
  [[ -f "$target" ]] || exit 0
  local where address pane errors text status=0
  where=$(< "$target")
  rm -f "$target"
  read -r address pane <<< "$where"

  errors=$(mktemp)
  trap 'rm -f "$errors"' EXIT
  text=$(hex dictation stop --print 2> "$errors") || status=$?
  case "$status" in
    0) ;;
    # No speech was heard.
    4) exit 0 ;;
    *)
      notify --urgency=critical "Dictation failed" "$(< "$errors")"
      exit "$status"
      ;;
  esac

  if [[ -n "$pane" ]]; then
    status=0
    deliver "$pane" "$text" || status=$?
    case "$status" in
      0) exit 0 ;;
      1)
        printf '%s' "$text" | wl-copy
        notify "Dictation copied" "OpenCode's prompt was not available: $text"
        exit 0
        ;;
    esac
  fi

  printf '%s' "$text" | wl-copy
  if [[ -n "$address" && "$(focused)" == "$where" ]]; then
    paste
  else
    notify "Dictation copied" "Focus moved, so it was not pasted: $text"
  fi
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  *)
    echo "usage: dictate start|stop" >&2
    exit 2
    ;;
esac
