# Notify user that Claude Code has completed a task
PWD_INFO=$(pwd | sed "s|^$HOME|~|")

# Get the last command from history for context
LAST_CMD=$(history | tail -1 | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' | cut -c1-50)

notify-send \
  --urgency=low \
  --icon=dialog-information \
  --app-name="Claude" \
  --expire-time=3000 \
  "Completed in $PWD_INFO" \
  "$LAST_CMD"
