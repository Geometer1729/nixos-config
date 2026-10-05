flake := justfile_directory()

# Show available commands
default:
  @just --list

# Update system configuration and commit changes
update:
  nh os switch -u "{{flake}}" && nix develop --command "git add . && git commit -m update"
  nix develop "{{flake}}" --command health --local

# Test configuration without switching
test:
  nh os test "{{flake}}"
  nix flake check "{{flake}}"
  nix develop "{{flake}}" --command health --local

# Build configuration
build:
  nh os build "{{flake}}"

# Format Nix files
fmt:
  nixpkgs-fmt "{{flake}}"

# Clean old generations (keep 3)
clean:
  ssh am nh clean all --keep 3 --optimise
  ssh torag nh clean all --keep 3 --optimise
  ssh balrog nh clean all --keep 3 --optimise

# Garbage collect Nix store
gc:
  nix-collect-garbage -d

# Clear failed systemd states to stop repeated notifications
clear-notos:
  systemctl --user reset-failed
  systemctl reset-failed

# edit the secrets file
secrets:
  mkdir -p ~/.config/sops/age
  ssh-to-age -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt
  sops edit ./modules/nixos/secrets/secrets.yaml

deploy:
  #!/usr/bin/env bash
  set -euo pipefail
  nixpkgs-fmt "{{flake}}"
  nix flake check "{{flake}}"
  for host in am balrog torag; do
    extra_args=()
    if [[ "$host" != am ]]; then
      extra_args+=(--use-substitutes)
    fi
    nh os switch "{{flake}}" -H "$host" --target-host "bbrian@$host" --elevation-strategy passwordless "${extra_args[@]}"
  done
