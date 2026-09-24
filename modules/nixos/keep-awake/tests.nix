{ runCommand, keep-awake }:
# Start processes that look like workloads (or merely mention them) and check
# what `keep-awake matches` recognizes.
runCommand "keep-awake-tests" { nativeBuildInputs = [ keep-awake ]; } ''
  mkdir bin
  echo 'sleep 60 & wait' >bin/work
  for name in nixos-rebuild .nixos-rebuild-wrapped nix just; do ln -s work "bin/$name"; done

  declare -A expected
  run() { local reason=$1; shift; "$@" & expected[$!]=$reason; }
  run "NixOS rebuild" bash bin/nixos-rebuild switch
  run "NixOS rebuild" bash bin/.nixos-rebuild-wrapped test
  run "Nix build" bash bin/nix --option builders "" build .#foo
  run "Nix flake check" bash bin/nix flake check
  run "Deployment" bash bin/just --justfile deploy deploy-devshell
  run "" bash -c 'nixos-rebuild test; sleep 60' 2>/dev/null
  run "" bash bin/nix eval --expr '"build"'
  run "" bash bin/just test
  sleep 1

  keep-awake matches | tee matches
  for pid in "''${!expected[@]}"; do
    actual=$(sed -n "s/: .* (PID $pid)$//p" matches)
    if [[ $actual != "''${expected[$pid]}" ]]; then
      echo "PID $pid: expected [''${expected[$pid]}], got [$actual]" >&2
      exit 1
    fi
  done
  kill "''${!expected[@]}" 2>/dev/null || true
  touch "$out"
''
