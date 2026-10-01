# Usage: task-promote <task id or uuid>
# Moves a task and every task it depends on, recursively, to next

source "$SCRIPTS_LIB/task-notes.sh"

ROOT=$(task _get "$1".uuid)
if [ -z "$ROOT" ]; then
  echo "No task $1" >&2
  exit 1
fi

declare -A SEEN
QUEUE=("$ROOT")
while ((${#QUEUE[@]})); do
  UUID="${QUEUE[0]}"
  QUEUE=("${QUEUE[@]:1}")
  [ -n "${SEEN[$UUID]:-}" ] && continue
  SEEN[$UUID]=1
  mapfile -t DEPS < <(task "$UUID" export | jq -r '.[0].depends // [] | .[]')
  QUEUE+=("${DEPS[@]}")
done

task rc.bulk=0 rc.confirmation=off "${!SEEN[@]}" status:pending modify +next -someday -waiting

# Sub tasks headers set the tags of new children, so they move to next too
for UUID in "${!SEEN[@]}"; do
  NOTE="$TASK_NOTES_DIR/$UUID.md"
  [ -e "$NOTE" ] || continue
  awk '
    /^## Sub tasks( \|\||$)/ {
      sub(/^## Sub tasks( \|\| ?)?/, "")
      n = split($0, parts, " ")
      filter = ""
      for (i = 1; i <= n; i++) {
        if (parts[i] == "+someday" || parts[i] == "+waiting" || parts[i] == "+next") continue
        filter = filter parts[i] " "
      }
      print "## Sub tasks || " filter "+next"
      next
    }
    { print }
  ' "$NOTE" > "$NOTE.tmp"
  if cmp -s "$NOTE" "$NOTE.tmp"; then
    rm "$NOTE.tmp"
  else
    mv "$NOTE.tmp" "$NOTE"
  fi
done
