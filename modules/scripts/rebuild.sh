unbuffer sudo nixos-rebuild test 2>&1 \
  | tee ~/Downloads/nixerr \
  || zsh
