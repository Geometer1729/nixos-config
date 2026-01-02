# Process inbox - GTD triage workflow
echo "=== GTD INBOX PROCESSING ==="
echo ""
task inbox

while true; do
  # Get list of tasks to process
  TASK_LIST=$(task status:pending -next -waiting -someday export | jq -r '.[] | "\(.id) \(.description)"')

  # Check if there are any tasks left
  if [ -z "$TASK_LIST" ]; then
    echo "Processing complete! Inbox is empty."
    exit 0
  fi

  echo ""
  echo "Select task to process (Ctrl-C to exit):"
  SELECTED=$(echo "$TASK_LIST" | fzf --select-1 --prompt="Process: " --preview 'task {} info' --preview-window=right:60%)

  if [ -z "$SELECTED" ]; then
    echo "Processing complete!"
    exit 0
  fi

  TASK_ID=$(echo "$SELECTED" | awk '{print $1}')

  echo ""
  printf "Processing task: \033[1m%s\033[0m\n" "$SELECTED"
  echo ""
  echo "What is it? (1-5)"
  echo "  1) Actionable - Next action (+next)"
  echo "  2) Waiting for someone/something (+waiting)"
  echo "  3) Someday/Maybe (+someday)"
  echo "  4) Multi-step project (assign project name)"
  echo "  5) Delete/Not actionable"
  echo ""
  read -r -p "Choice: " choice

  echo "$TASK_ID"

  case $choice in
    1)
      task "$TASK_ID" modify +next
      read -r -p "$(printf "@computer (y/\033[1mN\033[0m): ")" computer
      if [ "$computer" = "y" ]; then
        task "$TASK_ID" modify +@computer
      fi
      read -r -p "$(printf "@home (y/\033[1mN\033[0m): ")" home
      if [ "$home" = "y" ]; then
        task "$TASK_ID" modify +@home
      fi
      read -r -p "$(printf "@work (y/\033[1mN\033[0m): ")" work
      if [ "$work" = "y" ]; then
        task "$TASK_ID" modify +@work
      fi
      read -r -p "Additional tags (space-separated): " extra_tags
      if [ -n "$extra_tags" ]; then
        for tag in $extra_tags; do
          task "$TASK_ID" modify +"$tag"
        done
      fi
      read -r -p "Energy level (H/M/L): " energy
      if [ -n "$energy" ]; then
        task "$TASK_ID" modify energy:"$energy"
      fi
      read -r -p "Time estimate (e.g., 15m, 1h): " time
      if [ -n "$time" ]; then
        task "$TASK_ID" modify estimate:"$time"
      fi
      ;;
    2)
      task "$TASK_ID" modify +waiting
      read -r -p "Waiting for (who/what): " waitfor
      if [ -n "$waitfor" ]; then
        task "$TASK_ID" annotate "Waiting for: $waitfor"
      fi
      ;;
    3)
      task "$TASK_ID" modify +someday
      ;;
    4)
      read -r -p "Project name: " project
      if [ -n "$project" ]; then
        task "$TASK_ID" modify project:"$project"
      fi
      echo "Remember to add next actions for this project!"
      ;;
    5)
      task "$TASK_ID" delete
      ;;
    *)
      echo "Invalid choice, skipping..."
      ;;
  esac
done
