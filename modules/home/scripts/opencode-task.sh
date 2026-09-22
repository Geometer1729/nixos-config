#!/usr/bin/env bash

# VIT Shift+O: hand a task to an existing OpenCode tab group in ~/conf.
fail() {
  notify-send -u critical "OpenCode task" "$*"
  echo "$*" >&2
  exit 1
}

[[ $# == 1 && $1 =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]] ||
  fail "Select a task in VIT first."
uuid=$1
directory=$(realpath "$HOME/conf")

body=$(jq -nc --arg directory "$directory" '{location: {directory: $directory}}')
session=$(opencode api post /api/session --data "$body" | jq -er '.data.id') ||
  fail "Could not create the OpenCode session."

# Attach the skill explicitly: API text does not pass through TUI @ completion.
body=$(jq -nc --arg text "@taskwarrior $uuid" \
  '{text: $text, skills: [{id: "taskwarrior"}]}')
opencode api post "/api/session/$session/prompt" --data "$body" >/dev/null ||
  fail "Session $session was created, but its task prompt could not be sent."
notify-send "OpenCode task" "Task sent to OpenCode in ~/conf."
