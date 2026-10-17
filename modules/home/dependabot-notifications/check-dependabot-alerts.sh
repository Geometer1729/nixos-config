#!/usr/bin/env bash

# Notify once per boot about each open Dependabot alert in $DEPENDABOT_REPOS.
state="${XDG_RUNTIME_DIR:?}/dependabot-alerts"
touch "$state"

read -ra repos <<<"$DEPENDABOT_REPOS"
for repo in "${repos[@]}"; do
  alerts=$(gh api --paginate "repos/$repo/dependabot/alerts?state=open" \
    --jq '.[] | [.html_url, .security_advisory.severity, "\(.dependency.package.name): \(.security_advisory.summary)"] | @tsv')
  while IFS=$'\t' read -r url severity summary; do
    [[ -n "$url" ]] || continue
    grep -qxF "$url" "$state" && continue
    urgency=normal
    [[ "$severity" == critical || "$severity" == high ]] && urgency=critical
    notify-send --app-name=dependabot-alerts -u "$urgency" "Dependabot $severity: $repo" "$summary"
    echo "$url" >>"$state"
  done <<<"$alerts"
done
