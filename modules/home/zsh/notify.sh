#Notify me when a command finishes in an unfocused pane after more than 10 seconds
autoload -Uz add-zsh-hook

function is_window_focused() {
  if [[ -n "$WAYLAND_DISPLAY" ]]; then
    # On Wayland with Hyprland, use tmux to get terminal PID and check if it's focused
    if [[ -n "$TMUX" ]]; then
      local terminal_pid=$(tmux display-message -p '#{client_pid}' 2>/dev/null)
      local focused_pid=$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid' 2>/dev/null)
      [[ -n "$terminal_pid" && -n "$focused_pid" ]] && pgrep -P $focused_pid 2>/dev/null | grep $terminal_pid > /dev/null 2>&1
    else
      # Not in tmux don't notify
      return 0
    fi
  elif [[ -n "$DISPLAY" && -n "$WINDOWID" ]]; then
    # On X11, use xdotool to check if current window is active
    [[ "$WINDOWID" == "$(xdotool getactivewindow 2>/dev/null)" ]]
  else
    # Fallback don't notify?
    return 0
  fi
}

function notify_command_complete() {
  local command=$1
  local start_time=$2
  local exit=$3
  local end_time=$(date +%s)
  local elapsed=$((end_time - start_time))
  local session=$(tmux display-message -p "#S" 2>/dev/null)

  # Skip notifications if we can't access tmux or notify-send
  if ! command -v notify-send &>/dev/null || [[ -z "$session" ]]; then
    return 0
  fi

  if [[ $elapsed -gt 10 ]] &&
    { [ $(tmux display-message -p -t $TMUX_PANE '#{?pane_active,1,0}' 2>/dev/null) != 1 ] \
      || ! is_window_focused
    }
  then
    if [ $exit -eq 0 ]; then
      notify-send "$command" "Ran on $session taking $elapsed seconds" 2>/dev/null
    else
      notify-send -u critical "$command" "Failed wth $exit on $session after $elapsed seconds" 2>/dev/null
    fi
  fi
}

function preexec() {
  cmd=$1
  cmd_start_time=$(date +%s)
}

function precmd() {
  exit=$?
  if [[ -n $cmd ]]; then
    notify_command_complete "$cmd" $cmd_start_time "$exit"
    unset cmd cmd_start_time
  fi
}

add-zsh-hook preexec preexec
add-zsh-hook precmd precmd
