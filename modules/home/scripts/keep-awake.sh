#!/usr/bin/env bash

# hypridle suspends by shelling out to `systemctl suspend`, so a logind block
# inhibitor stops it without relying on hypridle noticing. Only sleep is
# inhibited, so the screen still locks on the normal timeout.
set -euo pipefail

duration="${1:-24h}"
host=$(uname -n)

# Replace any inhibitor already holding the machine awake
systemctl --user stop keep-awake.service 2>/dev/null || true

if [ "$duration" = off ]; then
  echo "$host: normal idle behaviour restored"
  exit 0
fi

# The transient service needs absolute paths from our packaged runtime inputs.
systemd-run --user --quiet \
  --unit=keep-awake \
  --description="Block automatic suspend" \
  --collect \
  "$(command -v systemd-inhibit)" \
    --what=sleep \
    --who=keep-awake \
    --why="keep-awake requested by $(id -un)" \
    --mode=block \
    "$(command -v sleep)" "$duration"

echo "$host will not suspend for $duration (cancel with: keep-awake off)"
