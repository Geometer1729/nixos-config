# shellcheck shell=bash
# Run a health command on another host. Its package is copied there first, so
# the host needs neither a checkout nor the same generation of the devshell.
run_remote() {
  local host=$1 program
  program=$(readlink -f "$2")
  shift 2
  nix copy --substitute-on-destination --to "ssh://bbrian@$host" "${program%/bin/*}"
  ssh -o BatchMode=yes "bbrian@$host" "${program@Q} ${*@Q}"
}
