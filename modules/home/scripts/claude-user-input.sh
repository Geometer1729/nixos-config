# Notify user that Claude Code needs input
PWD_INFO=$(pwd | sed "s|^$HOME|~|")

notify-send \
  --urgency=normal \
  --icon=dialog-question \
  --app-name="Claude" \
  --expire-time=0 \
  "Input needed" \
  "in $PWD_INFO"
