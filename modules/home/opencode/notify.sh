# Replace the aggregate OpenCode notification, discovering its ID from Mako.
# Only this short delivery operation needs a lock; session state stays in OpenCode.
exec 9>"$XDG_RUNTIME_DIR/opencode-notify.lock"
flock 9

# Click metadata belongs to the delivered popup, not a newly computed waiting list.
target_file="$XDG_RUNTIME_DIR/opencode-notify.target"
if [[ "${1-}" == "--focus" ]]; then
  target=$(jq -e --argjson id "${2?Expected a notification ID}" 'select(.id == $id)' "$target_file")
  flock -u 9
  jq -c '.sessionID' <<<"$target" | socat -T 2 - "UNIX-CONNECT:$(jq -r '.socket' <<<"$target")"
  exit 0
fi

summary="${1?Expected a notification summary (empty to clear)}"
body="${2-}"
key="${3-}"
session="${4-}"
socket="${5-}"
# Delivery receipt only: the waiting list is still rebuilt from OpenCode. Keeping
# this in /run makes dismissal survive refreshes/reloads, but not a new login.
receipt="$XDG_RUNTIME_DIR/opencode-notify.last"
fingerprint=$(printf '%s\0%s\0%s' "$summary" "$body" "$key" | sha256sum)
current=$(makoctl list -j | jq '[.[] | select(.app_name == "OpenCode" and .category == "opencode.waiting")]')

if [[ -z "$summary" ]]; then
  while read -r id; do
    makoctl dismiss --no-history -n "$id"
  done < <(jq -r '.[].id' <<<"$current")
  rm -f "$target_file"
  printf '%s\n' "$fingerprint" >"$receipt"
  exit 0
fi

# Recover cleanly even if an older process left duplicate aggregate notifications.
while read -r id; do
  makoctl dismiss --no-history -n "$id"
done < <(jq -r '.[1:][].id' <<<"$current")

# A missing popup with an unchanged receipt was dismissed. Repeated events,
# reconnects, and unrelated sessions must not resurrect it.
id=$(jq -r '.[0].id // 0' <<<"$current")
if [[ ! -f "$receipt" || "$(<"$receipt")" != "$fingerprint" ]]; then
  id=$(notify-send --print-id --app-name=OpenCode --category=opencode.waiting \
    --urgency=normal --expire-time=0 --replace-id="$id" -- "$summary" "$body")
  printf '%s\n' "$fingerprint" >"$receipt"
fi

# Refresh the socket address after service restarts even if the popup is unchanged.
jq -n --argjson id "$id" --arg sessionID "$session" --arg socket "$socket" \
  '{id: $id, sessionID: $sessionID, socket: $socket}' >"$target_file"
