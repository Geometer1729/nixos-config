# shellcheck shell=bash
set -euo pipefail

usage() {
  echo "Usage: local-deploy HOST ACTION [NIXOS-REBUILD_ARGS...]" >&2
  exit 2
}

[ "$#" -ge 2 ] || usage

host=$1
action=$2
shift 2

tailscale ping --c 3 --timeout 2s "$host" >/dev/null 2>&1 || true

mapfile -t endpoints < <(
  {
    tailscale status --json | jq -r --arg host "$host" '
      .Peer[]
      | select(.HostName == $host or .DNSName == $host)
      | .CurAddr
      | select(length > 0)
    '
    tailscale debug netmap | jq -r --arg host "$host" '
      .Peers[]
      | select(
          .Hostinfo.Hostname == $host
          or .Name == $host
          or (.Name | startswith($host + "."))
        )
      | .Endpoints[]?
    '
  } | jq -Rr '
    if startswith("[") then
      capture("^\\[(?<host>.*)\\]:[0-9]+$").host
    else
      capture("^(?<host>.*):[0-9]+$").host
    end
  ' | awk '!seen[$0]++'
)

[ "${#endpoints[@]}" -gt 0 ] || {
  echo "No Tailscale peer or endpoints found for $host" >&2
  exit 1
}

mapfile -t local_addresses < <(ip -j address | jq -r '.[].addr_info[].local')
target_ip=

for endpoint in "${endpoints[@]}"; do
  if printf '%s\n' "${local_addresses[@]}" | grep -Fxq -- "$endpoint"; then
    continue
  fi

  route=$(ip route get "$endpoint" 2>/dev/null) || continue
  case " $route " in
    *" dev tailscale0 "*) continue ;;
  esac

  private=false
  case "$endpoint" in
    10.* | 192.168.* | fc*:* | fd*:*) private=true ;;
    172.*)
      second_octet=${endpoint#172.}
      second_octet=${second_octet%%.*}
      if [ "$second_octet" -ge 16 ] && [ "$second_octet" -le 31 ]; then
        private=true
      fi
      ;;
  esac

  # A gateway route is still local when the LAN uses routed private subnets.
  if [[ " $route " == *" via "* ]] && [ "$private" != true ]; then
    continue
  fi

  if ! ssh \
    -o BatchMode=yes \
    -o ConnectTimeout=2 \
    -o ConnectionAttempts=1 \
    -o "HostKeyAlias=$host" \
    "bbrian@$endpoint" true </dev/null 2>/dev/null; then
    continue
  fi

  target_ip=$endpoint
  break
done

[ -n "$target_ip" ] || {
  echo "No reachable local endpoint found for $host; is it on the same network?" >&2
  exit 1
}

echo "Deploying $host directly to $target_ip"
nh os build -H "$host"

# Validate the IP against the host's existing SSH key rather than trusting an
# unrelated key recorded for a previously used address.
export NIX_SSHOPTS="-o HostKeyAlias=$host${NIX_SSHOPTS:+ $NIX_SSHOPTS}"
nixos-rebuild "$action" \
  --flake "$HOME/conf#$host" \
  --target-host "bbrian@$target_ip" \
  --use-substitutes \
  --sudo \
  "$@"
