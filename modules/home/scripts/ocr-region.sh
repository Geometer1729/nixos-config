# Select a screen region, OCR it, and copy the recognized text to the clipboard.
wayfreeze &
freeze_pid=$!
trap 'kill "$freeze_pid" 2>/dev/null || true' EXIT
sleep 0.1

# slurp exits non-zero when the selection is cancelled
if ! region=$(slurp); then
  exit 0
fi

if ! text=$(grim -g "$region" - | tesseract stdin stdout -l eng 2>/dev/null); then
  notify-send -u critical "OCR" "Text recognition failed"
  exit 1
fi

# tesseract ends pages with a form feed; drop trailing whitespace
text="${text%"${text##*[![:space:]]}"}"

if [[ -z "${text//[[:space:]]/}" ]]; then
  notify-send "OCR" "No text found"
  exit 1
fi

printf '%s' "$text" | wl-copy
notify-send "OCR" "Copied ${#text} characters"
