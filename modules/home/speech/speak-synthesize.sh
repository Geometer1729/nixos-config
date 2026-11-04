#!/usr/bin/env bash
# Synthesize stdin with Kokoro into the WAV file given as $1, for speak-play.

wav=$1
text=$(cat)
[[ -n "${text//[[:space:]]/}" ]] || exit 1

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
  --output-filename="$wav" \
  " $text" > /dev/null 2>&1; then
  logger -t speak "synthesis failed"
  exit 1
fi
logger -t speak "synthesized $(basename "$wav"): ${text:0:60}"
