# Notify user that Claude Code has completed a task

# Source helper functions
source "$SCRIPTS_LIB/claude-notify-helper.sh"

# Check if we should send notification
if ! should_notify "completed"; then
  exit 0
fi

# Get contextual information
PROJECT_INFO=$(get_project_info)
TIMESTAMP=$(date '+%H:%M:%S')

# Send notification
notify-send \
  --urgency=low \
  --icon="$CLAUDE_ICON" \
  --app-name="Claude Code" \
  --expire-time=4000 \
  "Claude completed at $TIMESTAMP" \
  "$PROJECT_INFO"
