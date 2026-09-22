source "$SCRIPTS_LIB/message.sh"
if [[ "$EXPECT_NOTIFY" == true ]]; then
  command -v notify-send >/dev/null
elif command -v notify-send >/dev/null; then
  echo "notify-send unexpectedly present in the headless toolbox" >&2
  exit 1
fi
printf '%s\n' "$GREETING:$message:$(choice)" | jq -R .
