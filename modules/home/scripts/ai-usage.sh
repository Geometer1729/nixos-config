#!/usr/bin/env bash

# OpenCode's usage plugin owns fetching/authentication. Both Waybars read this
# atomic, public-data-only runtime snapshot, so extra monitors never add polls.
CACHE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/opencode-ai-usage.json"
if [[ -r "$CACHE" ]] && jq -ce --argjson now "$(date +%s)" '
  if (.updatedAt | type) != "number" or (.text | type) != "string" or (.tooltip | type) != "string" then error("invalid snapshot")
  elif $now * 1000 - .updatedAt > 660000 then
    .text = (.text | sub(" \\?$"; "") + " ?") |
    .tooltip = "OpenCode usage monitor is stale. Start OpenCode to resume updates.\n\n" + .tooltip |
    .class += ["incomplete"]
  else . end | del(.updatedAt)
' "$CACHE" 2>/dev/null; then
  exit 0
fi

jq -cn '{text: "AI ?", class: ["incomplete"], tooltip: "Waiting for the OpenCode usage monitor. Open OpenCode to start fetching Claude and Codex limits."}'
