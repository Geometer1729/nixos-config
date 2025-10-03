#!/usr/bin/env bash
name=$1
# TODO it would probably be better to just name the scratchpad zsh
if [ "$name" = sp ]; then
  cmd="alacritty -t $name -e tmux new-session -A -s $name"
else
  cmd="alacritty -t $name -e tmux new-session -A -s $name $name"
fi

client=$(hyprctl -j clients | jq -r --arg title "$name" \
  '.[] | select(.title == "'"$name"'") | .address')

# Get current monitor size

hyprctl dispatch togglespecialworkspace special:"$name"

if ! [ "$client" ] ; then
  hyprctl dispatch exec "$cmd"
  #hyprctl dispatch togglefloating
fi

win="$(hyprctl -j monitors | jq -r \ '.[] | select(.focused)')"
width="$(echo "$win" | jq -r '.width')"
height="$(echo "$win" | jq -r '.height')"

hyprctl dispatch resizewindowpixel exact "$(("$width" / 2))" "$(("$height" / 2))"
hyprctl dispatch centerwindow
