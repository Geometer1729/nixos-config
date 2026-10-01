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

# Selecting mimics a left click, so use the on-button-left of the last matching
# section in mako's config, as mako does.
click_binding() {
  jq -Rnr --argjson n "$1" '
    reduce (inputs | select(. != "")) as $line ({criteria: {}, binding: "invoke-default-action"};
      if $line | startswith("[") then
        .criteria = ($line | .[1:-1] | split(" ") | map(split("=")
          | {key: (.[0] | gsub("-"; "_")), value: (.[1:] | join("="))}) | from_entries)
      elif ($line | startswith("on-button-left=")) and all(.criteria | to_entries[]; $n[.key] == .value) then
        .binding = ($line | ltrimstr("on-button-left="))
      else . end) | .binding
  ' "${XDG_CONFIG_HOME:-$HOME/.config}/mako/config"
}

activate() {
  local entry=$1 id binding app
  id=$(jq -r .id <<< "$entry")
  binding=$(click_binding "$entry")
  if [[ $binding == exec\ * ]]; then
    # mako runs exec bindings through sh with $id set.
    id=$id exec sh -c "$binding"
  fi
  if jq -e '.live and .actions.default' <<< "$entry" > /dev/null; then
    exec makoctl invoke -n "$id"
  fi
  if jq -e .live <<< "$entry" > /dev/null; then
    makoctl dismiss -n "$id"
  fi

  app=$(jq -r '.desktop_entry // .app_name // ""' <<< "$entry")
  # mako cannot invoke actions on expired notifications, so jump to the app instead.
  if [[ -n "$app" && $(hyprctl dispatch focuswindow "class:(?i)^${app//./\\.}$") == ok ]]; then
    exit 0
  fi
  jq -r '[.summary, .body // ""] | map(select(. != "")) | join("\n")' <<< "$entry" | wl-copy
}

case "${1:-history}" in
  history)
    notifications=$(jq -s '(.[0] | map(.live = true)) + .[1]' <(makoctl list -j) <(makoctl history -j))
    if [[ $(jq length <<< "$notifications") -eq 0 ]]; then
      notify-send "Notification history" "History is empty"
      exit 0
    fi

    index=$(jq -r '
      def one_line: gsub("[\u0000-\u001f]"; " ");
      .[] | (if .live then "● " else "" end)
        + "\(.app_name // "unknown" | one_line): \(.summary | one_line)"
        + (if (.body // "") != "" then " — \(.body | one_line)" else "" end)
    ' <<< "$notifications" | rofi -dmenu -i -p Notifications -format i -no-custom \
      -disable-history -mesg 'Enter: same as clicking it (● = still showing)') || exit 0
    [[ "$index" =~ ^[0-9]+$ ]] || exit 0

    activate "$(jq ".[$index]" <<< "$notifications")"
    ;;
  click)
    # Mako lists the topmost notification first.
    entry=$(makoctl list -j | jq '.[0] // empty | .live = true')
    [[ -n "$entry" ]] || exit 0
    activate "$entry"
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
    echo 'Usage: notification-center [history | click | dnd | waybar]' >&2
    exit 2
    ;;
esac
