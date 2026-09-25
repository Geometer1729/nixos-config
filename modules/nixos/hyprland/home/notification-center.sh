#!/usr/bin/env bash
set -euo pipefail

# Waybar's custom/notifications module refreshes on SIGRTMIN+8.
waybar_signal=8

waybar_status() {
  local modes count
  modes=$(makoctl mode)
  count=$(makoctl list -j | jq length)
  jq -nc --arg modes "$modes" --argjson count "$count" '
    ($modes | split("\n") | index("do-not-disturb") != null) as $dnd
    | {text: ((if $dnd then "🔕" else "🔔" end) + (if $count > 0 then " \($count)" else "" end)),
       class: (if $dnd then "dnd" elif $count > 0 then "pending" else "idle" end),
       tooltip: ([if $dnd then "Do Not Disturb: notifications go straight to history."
                  else "Notifications are shown." end,
                  "\($count) active",
                  "Click: toggle Do Not Disturb",
                  "Right click: history"] | join("\n"))}'
}

case "${1:-history}" in
  history)
    history=$(makoctl history -j)
    if [[ $(jq length <<< "$history") -eq 0 ]]; then
      notify-send "Notification history" "History is empty"
      exit 0
    fi

    index=$(jq -r '
      def one_line: gsub("[\u0000-\u001f]"; " ");
      .[] | "\(.app_name // "unknown" | one_line): \(.summary | one_line)"
        + (if (.body // "") != "" then " — \(.body | one_line)" else "" end)
    ' <<< "$history" | rofi -dmenu -i -p Notifications -format i -no-custom \
      -disable-history -mesg 'Enter: focus the sender, or copy the text if it has no window') || exit 0
    [[ "$index" =~ ^[0-9]+$ ]] || exit 0

    entry=$(jq ".[$index]" <<< "$history")
    app=$(jq -r '.desktop_entry // .app_name // ""' <<< "$entry")
    # mako cannot invoke actions on expired notifications, so jump to the app instead.
    if [[ -n "$app" && $(hyprctl dispatch focuswindow "class:(?i)^${app//./\\.}$") == ok ]]; then
      exit 0
    fi
    jq -r '[.summary, .body // ""] | map(select(. != "")) | join("\n")' <<< "$entry" | wl-copy
    ;;
  dnd)
    makoctl mode -t do-not-disturb > /dev/null
    pkill -RTMIN+"$waybar_signal" waybar || true
    ;;
  waybar)
    waybar_status ||
      echo '{"text": "🔔 !", "class": "error", "tooltip": "Notification state unavailable"}'
    ;;
  *)
    echo 'Usage: notification-center [history | dnd | waybar]' >&2
    exit 2
    ;;
esac
