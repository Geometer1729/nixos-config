#!/usr/bin/env bash

# Quick add task with optional note via taskopen

# Read task description
echo "Task description:"
read -r task_desc

if [ -z "$task_desc" ]; then
  echo "No task description provided. Exiting."
  "$HIDE_AFTER_REBUILD" && scratchPad vit hide
  exit 0
fi

# Create the task and get its ID
task_output=$(task add "$task_desc" 2>&1)
task_id=$(echo "$task_output" | grep -oP 'Created task \K\d+')

if [ -z "$task_id" ]; then
  echo "Failed to create task"
  sleep 2
  "$HIDE_AFTER_REBUILD" && scratchPad vit hide
  exit 1
fi

echo "Task $task_id created!"

# Ask if user wants to add a note
echo -n "Add note? (y/N): "
read -r answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
  # Open note in vim via taskopen
  taskopen "$task_id"
fi

"$HIDE_AFTER_REBUILD" && scratchPad vit hide
