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

# Switch to this checkout in its own unit, safe from OpenCode/sshd restarts
switch:
  #!/usr/bin/env bash
  set -euo pipefail
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  nh os build "{{flake}}" --out-link "$tmp/system"
  system=$(readlink -f "$tmp/system")
  sudo nix-env -p /nix/var/nix/profiles/system --set "$system"
  unit="switch-$(date +%s)"
  status=0
  sudo systemd-run --collect --wait --quiet --unit="$unit" "$system/bin/switch-to-configuration" switch || status=$?
  journalctl -u "$unit" -o cat --no-pager | grep -v '^sops-install-secrets: Imported'
  exit "$status"

# Build configuration
build:
  nh os build "{{flake}}"

# Format Nix files
fmt:
  nixpkgs-fmt "{{flake}}"

# Clean old generations (keep 3)
clean:
  ssh durin nh clean all --keep 3 --optimise
  ssh gimli nh clean all --keep 3 --optimise
  ssh narvi nh clean all --keep 3 --optimise

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

# Deploy this checkout (default: switch on every host)
deploy action="switch" *hosts:
  NH_FLAKE="{{flake}}" deploy {{action}} {{hosts}}
