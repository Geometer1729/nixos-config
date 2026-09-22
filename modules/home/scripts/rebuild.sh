if git -C ~/conf diff --quiet && git -C ~/conf diff --cached --quiet
then
  if ! git -C ~/conf pull --ff-only
  then
    zsh
    exit 1
  fi
else
  echo "Skipping git pull: ~/conf has staged or unstaged changes."
fi

if unbuffer nh os test ~/conf 2>&1 | tee ~/Downloads/nixerr
then
  # Hide scratchpad after successful rebuild if enabled
  "$HIDE_AFTER_REBUILD" && scratchPad sp hide
  exit
else
  zsh
fi
