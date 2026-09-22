#!/usr/bin/env bash

if ! url="$(wl-paste --no-newline)"; then
  notify-send --urgency=critical "Clean URL" "Could not read the clipboard"
  exit 1
fi

if ! result="$(python3 - "$url" <<'PY'
import sys
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

url = sys.argv[1]
parts = urlsplit(url)
if parts.scheme not in {"http", "https"} or not parts.netloc or "\n" in url or "\r" in url:
    raise SystemExit("clipboard does not contain an HTTP(S) URL")

tracking_names = {
    "_ga",
    "_gl",
    "dclid",
    "fbclid",
    "feature",
    "gclid",
    "gclsrc",
    "igshid",
    "li_fat_id",
    "mc_cid",
    "mc_eid",
    "mkt_tok",
    "msclkid",
    "ref",
    "ref_",
    "referral",
    "referrer",
    "rb_clickid",
    "s_cid",
    "si",
    "source",
    "source_id",
    "sourceid",
    "twclid",
    "vero_conv",
    "vero_id",
}

pairs = parse_qsl(parts.query, keep_blank_values=True)
kept = [
    (name, value)
    for name, value in pairs
    if not name.lower().startswith("utm_") and name.lower() not in tracking_names
]
removed = len(pairs) - len(kept)
cleaned = url if removed == 0 else urlunsplit(parts._replace(query=urlencode(kept, doseq=True)))

print(removed)
print(cleaned)
PY
)"; then
  notify-send --urgency=critical "Clean URL" "Clipboard does not contain a valid HTTP(S) URL"
  exit 1
fi

removed="${result%%$'\n'*}"
cleaned="${result#*$'\n'}"
printf '%s' "$cleaned" | wl-copy

if [ "$removed" -eq 0 ]; then
  notify-send "Clean URL" "No tracking parameters found"
else
  notify-send "Clean URL" "Removed $removed tracking parameter(s)"
fi
