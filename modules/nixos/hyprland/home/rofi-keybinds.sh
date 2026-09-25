#!/usr/bin/env bash
set -euo pipefail

# Optional JSON list of waybar click actions: [{module, button, command}].
click_actions=${1:-}

case "${ROFI_RETV:-0}" in
  0)
    printf '\0prompt\x1fKeybinds\n\0no-custom\x1ftrue\n'
    if ! binds=$(hyprctl -j binds); then
      printf '\0message\x1fCould not read Hyprland keybindings.\n'
      exit 1
    fi

    jq -r '
      def one_line: gsub("[\u0000-\u001f]"; " ");
      def shortcut:
        . as $bind |
        ([
          [4, "Ctrl"], [8, "Alt"], [64, "Super"], [1, "Shift"],
          [2, "CapsLock"], [16, "Mod2"], [32, "Mod3"], [128, "Mod5"]
        ] | map(select(($bind.modmask / .[0] | floor) % 2 == 1) | .[1])) +
        [if .keycode > 0 then "code:\(.keycode)"
         elif (.key | length) == 1 then .key | ascii_upcase
         else ({Return: "Enter", space: "Space", bracketleft: "[", bracketright: "]",
                Print: "PrintScreen", XF86AudioRaiseVolume: "VolumeUp",
                XF86AudioLowerVolume: "VolumeDown", XF86AudioMute: "Mute",
                XF86AudioPlay: "Play/Pause", XF86AudioNext: "NextTrack",
                XF86AudioPrev: "PreviousTrack"}[.key] // .key)
         end] | join("+");

      .[] |
      # Mouse drag actions require a held button and cannot be launched from a menu.
      select(.mouse | not) |
      shortcut as $shortcut |
      (if .description != "" then .description
       else [.dispatcher, .arg] | join(" ") end | one_line) as $description |
      $shortcut + (" " * ([2, 32 - ($shortcut | length)] | max)) + $description +
      (if .submap != "" then " [\(.submap)]" else "" end) +
      "\u0000info\u001f" + ({kind: "bind", dispatcher, arg} | tojson) +
      "\u001fmeta\u001f" + ([.dispatcher, .arg] | join(" ") | one_line)
    ' <<< "$binds"

    if [[ -r $click_actions ]]; then
      jq -r '
        def one_line: gsub("[\u0000-\u001f]"; " ");
        .[] |
        "Bar:\(.module | sub("^custom/"; "")) \(.button)" as $shortcut |
        (.command | gsub("/nix/store/[^/ ]+/bin/"; "") | one_line) as $description |
        $shortcut + (" " * ([2, 32 - ($shortcut | length)] | max)) + $description +
        "\u0000info\u001f" + ({kind: "waybar", command} | tojson) +
        "\u001fmeta\u001f" + (.command | one_line)
      ' "$click_actions"
    fi
    ;;
  1)
    kind=$(jq -er '.kind' <<< "$ROFI_INFO")
    # Rofi detaches scripts, so PPID is not Rofi. ROFI_OUTSIDE carries its PID.
    rofi_pid=$ROFI_OUTSIDE

    # Rofi waits for this script to finish before closing. Detach, then wait for
    # Rofi to exit so window actions and screenshots run after it releases focus.
    (
      tail --pid="$rofi_pid" --sleep-interval=0.05 -f /dev/null
      case "$kind" in
        bind)
          dispatcher=$(jq -er '.dispatcher' <<< "$ROFI_INFO")
          arg=$(jq -r '.arg' <<< "$ROFI_INFO")
          if ! result=$(hyprctl dispatch "$dispatcher" "$arg" 2>&1); then
            notify-send "Hyprland keybind failed" "$result"
          fi
          ;;
        waybar)
          command=$(jq -er '.command' <<< "$ROFI_INFO")
          # Waybar runs click actions through sh -c as well.
          if ! result=$(sh -c "$command" 2>&1); then
            notify-send "Waybar action failed" "$result"
          fi
          ;;
      esac
    ) </dev/null >/dev/null 2>&1 &
    ;;
esac
