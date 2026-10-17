#!/usr/bin/env bash

# Mako click action: hand open Dependabot alerts to an OpenCode tab group in ~/conf.
fail() {
  notify-send -u critical "OpenCode Dependabot" "$*"
  echo "$*" >&2
  exit 1
}

# A custom click action replaces mako's default dismissal.
if [[ -n "${1-}" ]]; then
  makoctl dismiss -n "$1" || true
fi

directory=$(realpath "$HOME/conf")
body=$(jq -nc --arg directory "$directory" '{location: {directory: $directory}, agent: "plan"}')
session=$(opencode api post /api/session --data "$body" | jq -er '.data.id') ||
  fail "Could not create the OpenCode session."

text="Investigate the open Dependabot alerts for: $DEPENDABOT_REPOS
List them with \`gh api 'repos/<repo>/dependabot/alerts?state=open'\`, trace how each vulnerable package is pulled in, assess whether the vulnerable code is actually reachable here, and propose a fix (upgrade, override, or dismissal with reason)."
body=$(jq -nc --arg text "$text" '{text: $text}')
opencode api post "/api/session/$session/prompt" --data "$body" >/dev/null ||
  fail "Session $session was created, but its prompt could not be sent."
