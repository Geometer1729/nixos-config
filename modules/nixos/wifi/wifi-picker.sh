interface=${WIFI_INTERFACE:?WIFI_INTERFACE is not set}

wpa() {
  wpa_cli -i "$interface" "$@"
}

fail() {
  printf '%s\n' "$1" >&2
  notify-send -u critical "Wi-Fi" "$1"
  exit 1
}

if ! wpa status >/dev/null; then
  fail "Cannot reach wpa_supplicant on $interface"
fi

printf 'Scanning on %s...\n' "$interface"
wpa scan >/dev/null || fail "Could not start a Wi-Fi scan"

scan_results=
for _ in {1..15}; do
  sleep 0.4
  scan_results=$(wpa scan_results)
  if [[ $(printf '%s\n' "$scan_results" | wc -l) -gt 1 ]]; then
    break
  fi
done

if ! selection=$(
  printf '%s\n' "$scan_results" \
    | tail -n +2 \
    | sort -t $'\t' -k3,3nr \
    | awk -F '\t' '$5 != "" && !seen[$5]++' \
    | fzf \
        --delimiter=$'\t' \
        --with-nth=5,3,4 \
        --header='SSID | signal | security' \
        --prompt='Wi-Fi> '
); then
  exit 0
fi

ssid=$(cut -f5- <<<"$selection")
flags=$(cut -f4 <<<"$selection")
network_id=$(
  wpa list_networks \
    | awk -F '\t' -v ssid="$ssid" 'NR > 1 && $2 == ssid { print $1; exit }'
)
new_network=

cleanup() {
  wpa enable_network all >/dev/null 2>&1 || true
  if [[ -n "$new_network" ]]; then
    wpa remove_network "$new_network" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [[ -z "$network_id" ]]; then
  network_id=$(wpa add_network)
  [[ "$network_id" =~ ^[0-9]+$ ]] || fail "Could not add $ssid"
  new_network=$network_id

  escaped_ssid=${ssid//\\/\\\\}
  escaped_ssid=${escaped_ssid//\"/\\\"}
  [[ $(wpa set_network "$network_id" ssid "\"$escaped_ssid\"") == OK ]] \
    || fail "Could not configure $ssid"

  if [[ "$flags" == *EAP* ]]; then
    fail "Enterprise Wi-Fi is not supported by this picker; use wpa_cli"
  elif [[ "$flags" == *OWE* ]]; then
    [[ $(wpa set_network "$network_id" key_mgmt OWE) == OK ]] \
      || fail "Could not configure OWE for $ssid"
  elif [[ "$flags" == *PSK* ]]; then
    IFS= read -r -s -p "Passphrase for $ssid: " passphrase </dev/tty
    printf '\n'
    psk=$(
      printf '%s\n' "$passphrase" \
        | wpa_passphrase "$ssid" \
        | awk '/^[[:space:]]*psk=[[:xdigit:]]+$/ { sub(/^[[:space:]]*psk=/, ""); print; exit }'
    )
    unset passphrase
    [[ ${#psk} -eq 64 ]] || fail "The passphrase must be between 8 and 63 characters"
    [[ $(wpa set_network "$network_id" psk "$psk") == OK ]] \
      || fail "Could not configure the passphrase for $ssid"
  elif [[ "$flags" == *SAE* ]]; then
    fail "WPA3-only Wi-Fi is not supported by this picker; use wpa_cli"
  elif [[ "$flags" == *WEP* ]]; then
    fail "WEP Wi-Fi is not supported by this picker; use wpa_cli"
  else
    [[ $(wpa set_network "$network_id" key_mgmt NONE) == OK ]] \
      || fail "Could not configure open Wi-Fi for $ssid"
  fi
fi

wpa select_network "$network_id" >/dev/null || fail "Could not select $ssid"

printf 'Connecting to %s...\n' "$ssid"
connected=false
for _ in {1..30}; do
  sleep 0.5
  status=$(wpa status)
  if grep -qx "id=$network_id" <<<"$status" && grep -qx 'wpa_state=COMPLETED' <<<"$status"; then
    connected=true
    break
  fi
done

[[ "$connected" == true ]] || fail "Could not connect to $ssid"

# Keep ad-hoc networks for this boot, but restore normal roaming among all profiles.
new_network=
wpa enable_network all >/dev/null
trap - EXIT
notify-send "Wi-Fi connected" "$ssid"
printf 'Connected to %s\n' "$ssid"
