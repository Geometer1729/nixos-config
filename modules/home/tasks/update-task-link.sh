# Usage: update-task-link "file/path.md" "heading-anchor" ["checklist-item"]
FILE_PATH="$1"
ANCHOR="$2"
CHECKLIST_ITEM="${3:-}"

# Select task using fzf
SELECTED=$(task status:pending export | jq -r '.[] | "\(.uuid) \(.description)"' | fzf --prompt="Select task to update: ")

if [ -z "$SELECTED" ]; then
  echo "No task selected"
  exit 1
fi

UUID=$(echo "$SELECTED" | awk '{print $1}')

# Update the redirect link - include checklist item if present
if [ -n "$CHECKLIST_ITEM" ]; then
  echo "[Redirect]($FILE_PATH#$ANCHOR)" > ~/Documents/vw/tasks/"$UUID".md
  echo "CHECKLIST:$CHECKLIST_ITEM" >> ~/Documents/vw/tasks/"$UUID".md
  echo "Updated task $UUID to point to $FILE_PATH#$ANCHOR (checklist item)"
else
  echo "[Redirect]($FILE_PATH#$ANCHOR)" > ~/Documents/vw/tasks/"$UUID".md
  echo "Updated task $UUID to point to $FILE_PATH#$ANCHOR"
fi
