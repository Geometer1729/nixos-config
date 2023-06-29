if playerctl status -a  | grep Playing
then
  echo something playing pausing everything
  playerctl pause -a
elif [[ "$(playerctl -l | wc -l)" -ge 2 ]]
then
  echo nothing playing multiple choices prompting user
  playerctl play -p "$(playerctl -l | dmenu)"
else
  echo nothing playing one thing to play playing it
  playerctl play
fi
