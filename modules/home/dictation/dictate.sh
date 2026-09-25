# Push-to-talk dictation: `dictate start` on key press, `dictate stop` on release.
# Records the default PipeWire source, transcribes it with whisper, and types the text.

state="$XDG_RUNTIME_DIR/dictation"
pidfile="$state/pid"
notifyfile="$state/notify-id"
recording="$state/rec.wav"

notify() {
  local id=0
  [[ -f "$notifyfile" ]] && id=$(<"$notifyfile")
  notify-send --print-id --replace-id="$id" --app-name=Dictation "$@" > "$notifyfile"
}

recorder_running() {
  [[ -f "$pidfile" ]] && kill -0 "$(<"$pidfile")" 2>/dev/null
}

start() {
  mkdir -p "$state"
  if recorder_running; then
    exit 0
  fi
  rm -f "$recording" "$notifyfile"
  pw-record --rate 16000 --channels 1 --format s16 "$recording" &
  echo $! > "$pidfile"
  notify --expire-time=0 "Listening…"
}

stop() {
  # The release can race the press when the key is tapped.
  for _ in {1..10}; do
    [[ -f "$pidfile" ]] && break
    sleep 0.05
  done
  [[ -f "$pidfile" ]] || exit 0

  pid=$(<"$pidfile")
  rm -f "$pidfile"
  kill -INT "$pid" 2>/dev/null || true
  for _ in {1..40}; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.05
  done

  # 16 kHz s16 mono is 32000 bytes/s; ignore accidental taps under ~0.3s.
  if [[ ! -f "$recording" ]] || (( $(stat -c %s "$recording") < 10000 )); then
    notify --expire-time=1000 "Too short, ignored"
    exit 0
  fi

  notify --expire-time=0 "Transcribing…"
  if ! raw=$(whisper-cli -m "$DICTATION_MODEL" -f "$recording" -l en -nt -np 2>"$state/whisper.log"); then
    notify --urgency=critical "Transcription failed" "See $state/whisper.log"
    exit 1
  fi

  # Segments arrive one per line; drop non-speech markers like [BLANK_AUDIO].
  text=$(printf '%s' "$raw" | tr '\n' ' ' | sed -E 's/\[[^]]*\]//g; s/ +/ /g; s/^ //; s/ $//')
  if [[ -z "$text" ]]; then
    notify --expire-time=1500 "No speech detected"
    exit 0
  fi

  printf '%s' "$text" | wtype -
  notify --expire-time=3000 "Typed" "$text"
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  *)
    echo "usage: dictate start|stop" >&2
    exit 2
    ;;
esac
