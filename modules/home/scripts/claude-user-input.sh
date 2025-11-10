# Notify user that Claude Code needs input

# Source helper functions
source "$SCRIPTS_LIB/claude-notify-helper.sh"

# Check if we should send notification
if ! should_notify "user-input"; then
  exit 0
fi

# Get contextual information
PROJECT_INFO=$(get_project_info)

# Send notification
notify-send \
  --urgency=normal \
  --icon="$CLAUDE_ICON" \
  --app-name="Claude Code" \
  --expire-time=0 \
  "Claude is ready" \
  "in $PROJECT_INFO"
