#Notify me when a command finishes in an unfocused pane after more than 10 seconds
autoload -Uz add-zsh-hook

function is_window_focused() {
  if [[ -n "$WAYLAND_DISPLAY" ]]; then
    # On Wayland with Hyprland, use tmux to get terminal PID and check if it's focused
    if [[ -n "$TMUX" ]]; then
      local terminal_pid=$(tmux display-message -p '#{client_pid}')
      local focused_pid=$(hyprctl activewindow -j | jq -r '.pid')
      pgrep -P $focused_pid | grep $terminal_pid > /dev/null
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
  local session=$(tmux display-message -p "#S")

  if [[ $elapsed -gt 10 ]] &&
    { [ $(tmux display-message -p -t $TMUX_PANE '#{?pane_active,1,0}') != 1 ] \
      || ! is_window_focused
    }
  then
    if [ $exit -eq 0 ]; then
      notify-send "$command" "Ran on $session taking $elapsed seconds"
    else
      notify-send -u critical "$command" "Failed wth $exit on $session after $elapsed seconds"
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
