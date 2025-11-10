# Usage: create-task-from-heading "Description" "file/path.md" "heading-anchor" ["checklist-item"]
DESCRIPTION="$1"
FILE_PATH="$2"
ANCHOR="$3"
CHECKLIST_ITEM="${4:-}"

# Create task with description
task add "$DESCRIPTION" >> /dev/null
UUID="$(task +LATEST uuids)"

# Create markdown file with link - include checklist item if present
if [ -n "$CHECKLIST_ITEM" ]; then
  echo "[Redirect]($FILE_PATH#$ANCHOR)" > ~/Documents/vw/tasks/"$UUID".md
  echo "CHECKLIST:$CHECKLIST_ITEM" >> ~/Documents/vw/tasks/"$UUID".md
  echo "Created task $UUID: $DESCRIPTION -> $FILE_PATH#$ANCHOR (checklist item)"
else
  echo "[Redirect]($FILE_PATH#$ANCHOR)" > ~/Documents/vw/tasks/"$UUID".md
  echo "Created task $UUID: $DESCRIPTION -> $FILE_PATH#$ANCHOR"
fi
