#!/usr/bin/env bash

# Mako click action: hand currently failed units to an OpenCode tab group in ~/conf.
fail() {
  notify-send -u critical "OpenCode failure" "$*"
  echo "$*" >&2
  exit 1
}

# A custom click action replaces mako's default dismissal.
if [[ -n "${1-}" ]]; then
  makoctl dismiss -n "$1" || true
fi

# Re-query rather than trusting the popup: units may have recovered since.
user=$(systemctl --user list-units --state=failed --no-legend --plain | awk 'NF {print $1}' | paste -sd ' ')
system=$(systemctl list-units --state=failed --no-legend --plain | awk 'NF {print $1}' | paste -sd ' ')
if [[ -z "$user" && -z "$system" ]]; then
  notify-send "OpenCode failure" "No failed units remain."
  exit 0
fi

directory=$(realpath "$HOME/conf")
body=$(jq -nc --arg directory "$directory" '{location: {directory: $directory}, agent: "plan"}')
session=$(opencode api post /api/session --data "$body" | jq -er '.data.id') ||
  fail "Could not create the OpenCode session."

text="Investigate these failed systemd units.
User units: ${user:-none}
System units: ${system:-none}
Check \`systemctl [--user] status\` and \`journalctl [--user] -b -u\` for each, compare against failures.md, and report the cause and a proposed fix."
body=$(jq -nc --arg text "$text" '{text: $text}')
opencode api post "/api/session/$session/prompt" --data "$body" >/dev/null ||
  fail "Session $session was created, but its prompt could not be sent."
