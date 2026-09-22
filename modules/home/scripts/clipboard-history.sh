#!/usr/bin/env bash

umask 077
runtime="${XDG_RUNTIME_DIR:?}/cliphist"
mkdir -p "$runtime"
workdir=$(mktemp -d "$runtime/picker.XXXXXXXX")
trap 'rm -rf -- "$workdir"' EXIT
trap 'exit 0' HUP INT TERM

query=""
while true; do
  if [[ ! -f "$runtime/db" ]]; then
    notify-send "Clipboard history" "History is empty"
    exit 0
  fi
  cliphist list > "$workdir/entries"
  if [[ ! -s "$workdir/entries" ]]; then
    notify-send "Clipboard history" "History is empty"
    exit 0
  fi
  mapfile -t entries < "$workdir/entries"

  # Rofi scales image icons itself. Keep decoded images private and remove them
  # when the picker closes, rather than using a persistent thumbnail cache.
  while IFS=$'\t' read -r id preview; do
    printf '%s\t%s' "$id" "$preview"
    if [[ "$preview" == "[[ binary data "* ]]; then
      if [[ -f "$workdir/$id" ]] || cliphist decode "$id" > "$workdir/$id"; then
        printf '\0icon\x1f%s' "$workdir/$id"
      fi
    fi
    printf '\n'
  done < "$workdir/entries" > "$workdir/rows"

  status=0
  # Rofi's normal cache contains persisted launcher history on this machine.
  # Give this invocation a disposable cache as well as disabling its history.
  result=$(XDG_CACHE_HOME="$workdir/cache" rofi \
    -dmenu -sync -i -p Clipboard -disable-history \
    -show-icons -l 8 -no-fixed-num-lines \
    -display-columns 2 -filter "$query" -format $'i\nf' \
    -theme-str 'element-icon { size: 3em; }' \
    -mesg 'Enter: copy · Delete: remove · Ctrl+Shift+Delete: clear all' \
    -kb-remove-char-forward Control+d \
    -kb-custom-1 Delete -kb-custom-2 Control+Shift+Delete \
    < "$workdir/rows") || status=$?
  index=${result%%$'\n'*}
  query=${result#*$'\n'}
  # -no-custom also blocks Clear when the filter matches no rows. Instead,
  # accept only a real row index for copy/delete, never the user's typed text.
  entry=""
  if [[ "$index" =~ ^[0-9]+$ ]] && (( index < ${#entries[@]} )); then
    entry=${entries[index]}
  fi

  case "$status" in
    0)
      [[ -n "$entry" ]] || continue
      # Decode to a file first so a failed lookup cannot clear the clipboard.
      # Avoid shell variables for clipboard data: they lose trailing newlines
      # and cannot represent image bytes.
      printf '%s\n' "$entry" | cliphist decode > "$workdir/selection"
      wl-copy < "$workdir/selection"
      exit 0
      ;;
    10)
      [[ -n "$entry" ]] || continue
      printf '%s\n' "$entry" | cliphist delete
      id=${entry%%$'\t'*}
      rm -f -- "$workdir/$id"
      ;;
    11)
      wl-copy --clear
      cliphist wipe
      exit 0
      ;;
    *) exit 0 ;;
  esac
done
