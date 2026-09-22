# Usage: taskopen-smart ~/Documents/vw/tasks/$UUID.md "Task Description"
TASK_FILE="$1"
TASK_DESCRIPTION="$2"

# Create file if it doesn't exist
if ! [ -e "$TASK_FILE" ]; then
  echo "# $TASK_DESCRIPTION" > "$TASK_FILE"
fi

# Check if file has a redirect link
if grep -q "^\[Redirect\]" "$TASK_FILE"; then
  # Check if file has a checklist item
  if grep -q "^CHECKLIST:" "$TASK_FILE"; then
    CHECKLIST_TEXT=$(grep "^CHECKLIST:" "$TASK_FILE" | sed 's/^CHECKLIST://')
    # Open file and follow link, then search for checklist item
    vim "$TASK_FILE" \
      -c "VimwikiFollowLink" \
      -c "normal! gg" \
      -c "call search('\\V$CHECKLIST_TEXT', 'c')"
  else
    # Just follow the link normally
    vim "$TASK_FILE" -c "VimwikiFollowLink"
  fi
else
  # No redirect, just edit the notes file
  vim "$TASK_FILE"
fi
