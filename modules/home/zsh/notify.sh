#Notify me when a command finishes in an unfocused pane after more than 10 seconds
autoload -Uz add-zsh-hook

function notify_command_complete() {
  local command=$1
  local start_time=$2
  local end_time=$(date +%s)
  local elapsed=$((end_time - start_time))

  if [[ $elapsed -gt 10 ]] &&
    { [ $(tmux display-message -p -t $TMUX_PANE '#{?pane_active,1,0}') != 1 ] \
      || [ "$WINDOWID" != "$(xdotool getactivewindow)" ]
    }
  then
    notify-send "$command finished" "In $elapsed seconds"
  fi
}

function preexec() {
  cmd=$1
  cmd_start_time=$(date +%s)
}

function precmd() {
  if [[ -n $cmd ]]; then
    notify_command_complete "$cmd" $cmd_start_time
    unset cmd cmd_start_time
  fi
}

add-zsh-hook preexec preexec
add-zsh-hook precmd precmd
