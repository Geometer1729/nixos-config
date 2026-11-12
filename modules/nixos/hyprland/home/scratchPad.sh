#!/usr/bin/env bash

name=$1
action=${2:-toggle}

if [ "$name" = sp ]; then
  cmd="/etc/profiles/per-user/bbrian/bin/ghostty --title=$name -e /etc/profiles/per-user/bbrian/bin/tmux new-session -A -s $name"
else
  cmd="/etc/profiles/per-user/bbrian/bin/ghostty --title=$name -e /etc/profiles/per-user/bbrian/bin/tmux new-session -A -s $name $name"
fi

client=$(hyprctl -j clients | jq -r --arg title "$name" '.[] | select(.title == $title) | .address')
is_visible=$(hyprctl -j activewindow | jq -r '.workspace.name' 2>/dev/null | grep -q "^special:$name" && echo "yes" || echo "")

toggle(){
  hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$name\")"
}

launch(){
  if ! [ "$client" ] ; then
    hyprctl dispatch "hl.dsp.exec_cmd([==[$cmd]==])"

    # Wait for the window to actually appear (up to 3 seconds)
    timeout=30  # 3 seconds with 0.1s intervals
    while [ $timeout -gt 0 ]; do
      client=$(hyprctl -j clients | jq -r --arg title "$name" \
        '.[] | select(.title == "'"$name"'") | .address')
      if [ "$client" ]; then
        break
      fi
      sleep 0.1
      timeout=$((timeout - 1))
    done

  else
    # Refit an existing scratchpad to half the monitor it was summoned on.
    hyprctl dispatch 'function()
      local monitor = hl.get_active_monitor()
      hl.dispatch(hl.dsp.window.resize({ x = monitor.width / monitor.scale / 2, y = monitor.height / monitor.scale / 2 }))
      hl.dispatch(hl.dsp.window.center())
    end'
  fi
}


case "$action" in
  hide)
    [ "$client" ] && hyprctl dispatch "hl.dsp.window.close({ window = \"address:$client\" })"
    ;;
  show)
    if [ -z "$is_visible" ]; then
      toggle
      launch
    fi
    ;;
  *)
    toggle
    launch
    ;;
esac
