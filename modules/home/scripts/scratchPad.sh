#!/usr/bin/env bash
name=$1
# TODO it would probably be better to just name the scratchpad zsh
if [ "$name" = sp ]; then
  cmd="/etc/profiles/per-user/bbrian/bin/alacritty -t $name -e /etc/profiles/per-user/bbrian/bin/tmux new-session -A -s $name"
else
  cmd="/etc/profiles/per-user/bbrian/bin/alacritty -t $name -e /etc/profiles/per-user/bbrian/bin/tmux new-session -A -s $name $name"
fi

echo "$cmd"

client=$(hyprctl -j clients | jq -r --arg title "$name" \
  '.[] | select(.title == "'"$name"'") | .address')

# Get current monitor size

hyprctl dispatch togglespecialworkspace special:"$name"

if ! [ "$client" ] ; then
  hyprctl dispatch exec "$cmd"
  sleep 0.1
  hyprctl dispatch togglefloating
fi

hyprctl dispatch resizeactive exact 50% 50%
hyprctl dispatch centerwindow
