if unbuffer sudo nixos-rebuild test 2>&1 | tee ~/Downloads/nixerr
then
  "$HIDE_SP_AFTER_REBUILD" && xmonadctl 1
  exit
else
  zsh
fi
