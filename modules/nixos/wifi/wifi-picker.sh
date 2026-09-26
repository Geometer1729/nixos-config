interface=${WIFI_INTERFACE:?WIFI_INTERFACE is not set}

wpa() {
  wpa_cli -i "$interface" "$@"
}

list_networks() {
  wpa scan_results \
    | tail -n +2 \
    | sort -t $'\t' -k3,3nr \
    | awk -F '\t' '$5 != "" && !seen[$5]++'
}

if [[ ${1:-} == --list ]]; then
  list_networks
  exit 0
fi

fail() {
  printf '%s\n' "$1" >&2
  notify-send -u critical "Wi-Fi" "$1"
  exit 1
}

trap 'notify-send -u critical "Wi-Fi" "wifi-picker failed at line $LINENO: $BASH_COMMAND"' ERR

if ! wpa status >/dev/null; then
  fail "Cannot reach wpa_supplicant on $interface"
fi

printf 'Scanning on %s...\n' "$interface"
wpa scan >/dev/null || fail "Could not start a Wi-Fi scan"

for _ in {1..15}; do
  sleep 0.4
  if [[ $(wpa scan_results | wc -l) -gt 1 ]]; then
    break
  fi
done

# --track blocks input while a reload runs, so scan outside fzf and only reload cached results.
fzf_dir=$(mktemp -d)
socket=$fzf_dir/fzf.sock
(
  while sleep 1; do
    wpa scan >/dev/null || true
    sleep 4
    curl -s --unix-socket "$socket" -X POST http://localhost \
      -d "reload-sync(${0@Q} --list)" >/dev/null || true
  done
) &
refresher=$!

selection=$(
  list_networks \
    | fzf \
        --delimiter=$'\t' \
        --with-nth=5,3,4 \
        --id-nth=5 \
        --track \
        --with-shell="$BASH -c" \
        --listen-unsafe="$socket" \
        --header='SSID | signal | security (rescans every 5s)' \
        --prompt='Wi-Fi> '
) || selection=
kill "$refresher" 2>/dev/null || true
rm -rf "$fzf_dir"
[[ -n "$selection" ]] || exit 0

# wpa_cli prints SSIDs escaped (\xNN, \", \\, \e, \n, \r, \t); printf %b decodes all but \".
ssid_txt=$(cut -f5- <<<"$selection")
ssid=$(printf '%b' "${ssid_txt//\\\"/\"}")
ssid_hex=$(printf '%b' "${ssid_txt//\\\"/\"}" | od -An -v -tx1 | tr -d ' \n')
flags=$(cut -f4 <<<"$selection")
network_id=$(
  wpa list_networks \
    | SSID_TXT=$ssid_txt awk -F '\t' 'NR > 1 && $2 == ENVIRON["SSID_TXT"] { print $1; exit }'
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

  [[ $(wpa set_network "$network_id" ssid "$ssid_hex") == OK ]] \
    || fail "Could not configure $ssid"

  if [[ "$flags" == *EAP* ]]; then
    fail "Enterprise Wi-Fi is not supported by this picker; use wpa_cli"
  elif [[ "$flags" == *OWE* ]]; then
    [[ $(wpa set_network "$network_id" key_mgmt OWE) == OK ]] \
      || fail "Could not configure OWE for $ssid"
  elif [[ "$flags" == *PSK* ]]; then
    printf 'Passphrase for %s: ' "$ssid"
    # wpa_passphrase requires a terminal on stdin; it disables echo itself.
    psk=$(
      wpa_passphrase "$ssid" </dev/tty 2>/dev/null \
        | awk '/^[[:space:]]*psk=[[:xdigit:]]+$/ { sub(/^[[:space:]]*psk=/, ""); print; exit }'
    ) || psk=
    printf '\n'
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
