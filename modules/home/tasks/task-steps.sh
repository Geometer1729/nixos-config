# Usage: task-steps <task id or uuid>
# Opens the task's taskwiki list on a new child line so it can be broken into steps

source "$SCRIPTS_LIB/task-notes.sh"

UUID=$(task _get "$1".uuid)
if [ -z "$UUID" ]; then
  echo "No task $1" >&2
  exit 1
fi
DESCRIPTION=$(task _get "$UUID".description)
NOTE="$TASK_NOTES_DIR/$UUID.md"

ensure_task_note "$UUID" "$DESCRIPTION"
FILE=$(redirect_target "$NOTE") || FILE="$NOTE"

LINE=$(grep -n -m1 -P "$(task_line_regex "$UUID")" "$FILE" | cut -d: -f1 || true)
if [ -n "$LINE" ]; then
  # Nest a new child directly under the task's existing line
  awk -v at="$LINE" '
    { print }
    NR == at { match($0, /^[ \t]*/); print substr($0, 1, RLENGTH) "  * [ ] " }
  ' "$FILE" > "$FILE.tmp"
  mv "$FILE.tmp" "$FILE"
  CURSOR=$((LINE + 1))
else
  # Preset header so new children inherit the task's project and tags
  FILTER=""
  PROJECT=$(task _get "$UUID".project)
  [ -n "$PROJECT" ] && FILTER="project:$PROJECT"
  IFS=',' read -r -a TAGS <<< "$(task _get "$UUID".tags)"
  for TAG in "${TAGS[@]}"; do
    FILTER="${FILTER:+$FILTER }+$TAG"
  done
  HEADER="## Sub tasks${FILTER:+ || $FILTER}"
  printf '\n%s\n* [ ] %s  #%s\n  * [ ] \n' "$HEADER" "$DESCRIPTION" "${UUID:0:8}" >> "$FILE"
  CURSOR=$(wc -l < "$FILE")
fi

vim "+$CURSOR" "+startinsert!" "$FILE"

# Drop child lines left empty
sed -i -E '/^\s*\* \[ \]\s*$/d' "$FILE"
