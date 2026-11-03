#!/usr/bin/env bash
# Speak stdin aloud with Kokoro. Killing the process group stops it mid-sentence.

text=$(cat)
[[ -n "${text//[[:space:]]/}" ]] || exit 0

workdir=$(mktemp -d)
# Media players this paused, resumed however speech ends.
paused=()
# shellcheck disable=SC2329 # Called from the EXIT trap.
resume() {
  for player in "${paused[@]}"; do
    playerctl --player="$player" play 2> /dev/null || true
  done
}
trap 'resume; rm -rf "$workdir"' EXIT
# The journal (`journalctl --user -t speak`) shows what played and what was cut off.
trap 'logger -t speak "stopped"; exit 143' TERM

# A leading space keeps text starting with "--" from parsing as an option.
if ! sherpa-onnx-offline-tts \
  --debug=0 \
  --kokoro-model="$KOKORO/model.onnx" \
  --kokoro-voices="$KOKORO/voices.bin" \
  --kokoro-tokens="$KOKORO/tokens.txt" \
  --kokoro-data-dir="$KOKORO/espeak-ng-data" \
  --kokoro-lexicon="$KOKORO/lexicon-us-en.txt" \
  --num-threads=8 \
  --sid="$KOKORO_SPEAKER" \
  --output-filename="$workdir/speech.wav" \
  " $text" > /dev/null 2>&1; then
  logger -t speak "synthesis failed"
  exit 1
fi

# Pause only once the speech is ready, so media keeps playing during synthesis.
mapfile -t players < <(playerctl --list-all 2> /dev/null)
for player in "${players[@]}"; do
  if [[ "$(playerctl --player="$player" status 2> /dev/null)" == Playing ]] \
    && playerctl --player="$player" pause 2> /dev/null; then
    paused+=("$player")
  fi
done

logger -t speak "playing: ${text:0:60}${paused[*]:+ (paused ${paused[*]})}"
status=0
pw-play "$workdir/speech.wav" || status=$?
logger -t speak "finished (pw-play exit $status)"
exit "$status"
