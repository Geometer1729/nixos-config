# Run the program tmux-resurrect saved for this pane (tagged by the tmux
# `restore-commands` hook) at the first prompt, after direnv has loaded, as if
# it were typed. Keys typed ahead by tmux could be lost during slow startup.
if [[ -n $TMUX_PANE ]]; then
  zmodload zsh/datetime
  autoload -Uz add-zle-hook-widget

  _tmux_restore_command() {
    (( ${+_tmux_restore_checked} )) && return
    typeset -g _tmux_restore_checked=1

    # Tags are set once the restore finishes; ignore a flag left by a failed one.
    local started command
    repeat 150; do
      started=$(tmux show-options -gqv @restoring 2>/dev/null)
      [[ -z $started ]] && break
      (( EPOCHSECONDS - started > 60 )) && break
      sleep 0.2
    done

    tmux set-option -pu -t "$TMUX_PANE" @restored 2>/dev/null
    command=$(tmux show-options -pqv -t "$TMUX_PANE" @restore-command 2>/dev/null)
    [[ -n $command ]] || return
    tmux set-option -pu -t "$TMUX_PANE" @restore-command
    BUFFER=$command
    zle accept-line
  }
  add-zle-hook-widget line-init _tmux_restore_command
fi
