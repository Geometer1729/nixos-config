while true
do
  calcurse -n -l 1 | sed '1d;s/^ *//'
  sleep 1
done
