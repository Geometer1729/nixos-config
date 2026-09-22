if ! [ -e "$1" ]
then
  echo \# "$2" >> "$1"
fi
vim "$1"
