#!/usr/bin/env bash
# Play the WAV file $1, pausing media meanwhile. Killing the process group stops it mid-sentence.

wav=$1
# Media players this paused, resumed however speech ends.
paused=()
# shellcheck disable=SC2329 # Called from the EXIT trap.
resume() {
  for player in "${paused[@]}"; do
    playerctl --player="$player" play 2> /dev/null || true
  done
}
trap resume EXIT
# The journal (`journalctl --user -t speak`) shows what played and what was cut off.
trap 'logger -t speak "stopped"; exit 143' TERM

mapfile -t players < <(playerctl --list-all 2> /dev/null)
for player in "${players[@]}"; do
  if [[ "$(playerctl --player="$player" status 2> /dev/null)" == Playing ]] \
    && playerctl --player="$player" pause 2> /dev/null; then
    paused+=("$player")
  fi
done

logger -t speak "playing $(basename "$wav")${paused[*]:+ (paused ${paused[*]})}"
status=0
pw-play "$wav" || status=$?
logger -t speak "finished (pw-play exit $status)"
exit "$status"
