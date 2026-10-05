# shellcheck shell=bash
set -euo pipefail

usage() {
  echo "Usage: deploy (switch|boot|test|build) [HOST...]" >&2
  echo "Deploys \$NH_FLAKE to each HOST (default: am balrog torag)." >&2
  exit 2
}

[ "$#" -ge 1 ] || usage
action=$1
shift
case $action in
  switch | boot | test | build) ;;
  *) usage ;;
esac

hosts=("$@")
[ "${#hosts[@]}" -gt 0 ] || hosts=(am balrog torag)

for host in "${hosts[@]}"; do
  nh os "$action" "${NH_FLAKE:-$HOME/conf}" -H "$host" --target-host "bbrian@$host" --elevation-strategy passwordless
done
