# Notify user about OpenCode attention events

source "$SCRIPTS_LIB/claude-notify-helper.sh"

EVENT_TYPE="${1:-ready}"
PROJECT_DIR="${2:-$PWD}"

case "$EVENT_TYPE" in
  permission)
    NOTIFY_TYPE="opencode-permission"
    URGENCY="normal"
    EXPIRE_TIME=0
    TITLE="OpenCode needs approval"
    ;;
  *)
    NOTIFY_TYPE="opencode-ready"
    URGENCY="low"
    EXPIRE_TIME=4000
    TITLE="OpenCode is ready"
    ;;
esac

if ! should_notify "$NOTIFY_TYPE"; then
  exit 0
fi

PROJECT_INFO=$(get_project_info "$PROJECT_DIR")

notify-send \
  --urgency="$URGENCY" \
  --app-name="OpenCode" \
  --expire-time="$EXPIRE_TIME" \
  "$TITLE" \
  "in $PROJECT_INFO"
