#!/usr/bin/env bash
# Verify all configured syncthing peers are connected.
config="$HOME/.local/state/syncthing/config.xml"
key=$(sed -nE 's|.*<apikey>(.*)</apikey>.*|\1|p' "$config")
if [[ -z $key ]]; then
  echo "syncthing: could not read api key from $config" >&2
  exit 1
fi

if ! conns=$(curl -fsS -H "X-API-Key: $key" http://127.0.0.1:8384/rest/system/connections); then
  echo "syncthing: api request failed" >&2
  exit 1
fi

if jq -e '.connections | length > 0 and all(.[]; .connected)' <<<"$conns" >/dev/null; then
  echo "syncthing: ok ($(jq '.connections | length' <<<"$conns") peers)"
else
  bad=$(jq -r '.connections | to_entries | map(select(.value.connected | not) | .key[:7]) | join(", ")' <<<"$conns")
  echo "syncthing: peer(s) disconnected: ${bad:-<no peers configured>}" >&2
  exit 1
fi
