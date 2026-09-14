# Replace the aggregate OpenCode notification, discovering its ID from Mako.
# Only this short delivery operation needs a lock; session state stays in OpenCode.
exec 9>"$XDG_RUNTIME_DIR/opencode-notify.lock"
flock 9

summary="${1?Expected a notification summary (empty to clear)}"
body="${2-}"
key="${3-}"
# Delivery receipt only: the waiting list is still rebuilt from OpenCode. Keeping
# this in /run makes dismissal survive refreshes/reloads, but not a new login.
receipt="$XDG_RUNTIME_DIR/opencode-notify.last"
fingerprint=$(printf '%s\0%s\0%s' "$summary" "$body" "$key" | sha256sum)
current=$(makoctl list -j | jq '[.[] | select(.app_name == "OpenCode" and .category == "opencode.waiting")]')

if [[ -z "$summary" ]]; then
  while read -r id; do
    makoctl dismiss --no-history -n "$id"
  done < <(jq -r '.[].id' <<<"$current")
  printf '%s\n' "$fingerprint" >"$receipt"
  exit 0
fi

# Recover cleanly even if an older process left duplicate aggregate notifications.
while read -r id; do
  makoctl dismiss --no-history -n "$id"
done < <(jq -r '.[1:][].id' <<<"$current")

# A missing popup with an unchanged receipt was dismissed. Repeated events,
# reconnects, and unrelated sessions must not resurrect it.
if [[ -f "$receipt" && "$(<"$receipt")" == "$fingerprint" ]]; then
  exit 0
fi

id=$(jq -r '.[0].id // 0' <<<"$current")
notify-send --app-name=OpenCode --category=opencode.waiting \
  --urgency=normal --expire-time=0 --replace-id="$id" -- "$summary" "$body"
printf '%s\n' "$fingerprint" >"$receipt"
