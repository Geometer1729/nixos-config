# Run every local health check on each host, then the fleet's remote builds.
usage() {
  echo "Usage: health [--local] [HOST...]"
  echo "Runs the local health checks on each HOST (default: this machine),"
  echo "then remote-builds-health unless --local is given."
}

local_only=false
hosts=()
for arg in "$@"; do
  case $arg in
    --local) local_only=true ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      usage >&2
      exit 2
      ;;
    *) hosts+=("$arg") ;;
  esac
done

source "$SCRIPTS_LIB/remote.sh"

failed=()
check() {
  local name=$1
  shift
  echo "=== $name ==="
  "$@" || failed+=("$name")
  echo
}

self=$(readlink -f "${BASH_SOURCE[0]}")
this_host=$(uname -n)
for host in "${hosts[@]:-$this_host}"; do
  if [[ $host == "$this_host" ]]; then
    for command in systemd-health disk-health syncthing-health vim-health gnome-health; do
      check "$host $command" "$command"
    done
  else
    check "$host" run_remote "$host" "$self" --local
  fi
done

$local_only || check remote-builds-health remote-builds-health

if ((${#failed[@]})); then
  echo "health: failed: ${failed[*]}" >&2
  exit 1
fi
echo "health: all checks passed"
