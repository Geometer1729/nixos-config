if unbuffer nh os test ~/conf 2>&1 | tee ~/Downloads/nixerr
then
  # Hide scratchpad after successful rebuild if enabled
  "$HIDE_SP_AFTER_REBUILD" && scratchPad sp hide
  exit
else
  zsh
fi
