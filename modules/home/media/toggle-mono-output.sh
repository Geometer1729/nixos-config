mono_sink=mono-output
unit=mono-output.service
state_file="${XDG_RUNTIME_DIR:?}/mono-output-original-sink"

if systemctl --user is-active --quiet "$unit"; then
  original_sink=$(<"$state_file")
  sink_exists=false
  fallback_sink=
  while IFS=$'\t' read -r _ sink _; do
    [[ $sink == "$original_sink" ]] && sink_exists=true
    if [[ -z $fallback_sink && $sink != "$mono_sink" ]]; then
      fallback_sink=$sink
    fi
  done < <(pactl list short sinks)

  if [[ $sink_exists != true ]]; then
    original_sink=$fallback_sink
  fi

  if [[ -n $original_sink ]]; then
    pactl set-default-sink "$original_sink"
    while IFS=$'\t' read -r input _; do
      pactl move-sink-input "$input" "$original_sink"
    done < <(pactl list short sink-inputs)
  fi

  systemctl --user stop "$unit"
  rm -f "$state_file"
  notify-send "Audio output" "Stereo"
else
  original_sink=$(pactl get-default-sink)
  printf '%s\n' "$original_sink" >"$state_file"
  systemctl --user reset-failed "$unit" 2>/dev/null || true
  systemd-run --user --unit="$unit" --collect \
    "$(command -v pw-loopback)" \
    --name mono-loopback \
    --capture-props="node.name=$mono_sink node.description=Mono media.class=Audio/Sink audio.position=[ MONO ]" \
    --playback="$original_sink" \
    --playback-props='audio.position=[ FL FR ] node.passive=true' >/dev/null

  for _ in {1..20}; do
    while IFS=$'\t' read -r _ sink _; do
      [[ $sink == "$mono_sink" ]] && break 2
    done < <(pactl list short sinks)
    sleep 0.1
  done

  if ! pactl set-default-sink "$mono_sink"; then
    systemctl --user stop "$unit"
    rm -f "$state_file"
    notify-send --urgency=critical "Audio output" "Could not enable mono"
    exit 1
  fi

  while IFS=$'\t' read -r input _; do
    pactl move-sink-input "$input" "$mono_sink"
  done < <(pactl list short sink-inputs)
  notify-send "Audio output" "Mono"
fi
