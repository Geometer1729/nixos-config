#!/usr/bin/env bash

# Mako click action: open an OpenCode session for each failure task the popup
# lists, as "<unit> (task <short uuid>)" lines. Mirrored popups from another
# desktop work too, once its task has synced.
fail() {
  notify-send -u critical "OpenCode failure" "$*"
  echo "$*" >&2
  exit 1
}

id=${1:?usage: opencode-failure <mako notification id>}

# Expired notifications are only in history.
body=$(jq -sr --argjson id "$id" 'add | map(select(.id == $id))[0].body // empty' \
  <(makoctl list -j) <(makoctl history -j)) ||
  fail "Could not read notification $id."
# A custom click action replaces mako's default dismissal.
makoctl dismiss -n "$id" || true

mapfile -t short < <(grep -oE '\(task [[:xdigit:]]{8}\)' <<<"$body" | grep -oE '[[:xdigit:]]{8}')
((${#short[@]})) || fail "Notification $id names no failure task."

task sync >/dev/null 2>&1 || true
for prefix in "${short[@]}"; do
  uuid=$(task rc.verbose=nothing rc.context= "$prefix" _uuids | head -n1)
  if [[ -z $uuid ]]; then
    notify-send "OpenCode failure" "Task $prefix hasn't synced here yet; try again in a few minutes."
    continue
  fi
  opencode-start --task "$uuid" >/dev/null || true
done
