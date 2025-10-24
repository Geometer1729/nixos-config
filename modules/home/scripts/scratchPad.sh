#!/usr/bin/env bash

name=$1
action=${2:-toggle}

if [ "$name" = sp ]; then
  cmd="/etc/profiles/per-user/bbrian/bin/alacritty -t $name -e /etc/profiles/per-user/bbrian/bin/tmux new-session -A -s $name"
else
  cmd="/etc/profiles/per-user/bbrian/bin/alacritty -t $name -e /etc/profiles/per-user/bbrian/bin/tmux new-session -A -s $name $name"
fi

client=$(hyprctl -j clients | jq -r --arg title "$name" '.[] | select(.title == $title) | .address')
is_visible=$(hyprctl -j activewindow | jq -r '.workspace.name' 2>/dev/null | grep -q "^special:$name" && echo "yes" || echo "")

toggle(){
  hyprctl dispatch togglespecialworkspace special:"$name"
}

launch(){
  if ! [ "$client" ] ; then
    hyprctl dispatch exec "$cmd"

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

    if [ "$client" ]; then
      hyprctl dispatch togglefloating
    fi
  fi
  hyprctl dispatch resizeactive exact 50% 50%
  hyprctl dispatch centerwindow
}


case "$action" in
  hide)
    [ "$is_visible" ] && toggle
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
