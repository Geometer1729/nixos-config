# Usage: task-dailies
# Adds today's dailies from the wiki's recur.md; `until` expires them at midnight.
# Each bullet under "## Daily" is passed to `task add`, so it may carry
# attributes. The bullet is kept in the `routine` UDA to identify it across days.

source "$SCRIPTS_LIB/task-notes.sh"

RECUR="$TASK_NOTES_DIR/recur.md"

task sync || echo "Sync failed, continuing with local replica" >&2

mapfile -t EXISTING < <(task +daily entry.after:today export | jq -r '.[].routine // empty')
mapfile -t DAILIES < <(awk '/^## /{ d = ($0 ~ /^## Daily[[:space:]]*$/) } d && sub(/^- +/, "")' "$RECUR")

for LINE in "${DAILIES[@]}"; do
  for SEEN in "${EXISTING[@]}"; do
    [ "$SEEN" = "$LINE" ] && continue 2
  done
  read -ra ARGS <<<"$LINE"
  task add "${ARGS[@]}" +daily +next due:eod until:tomorrow routine:"$LINE"
done

task sync || echo "Sync failed" >&2
