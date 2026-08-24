flake := justfile_directory()

# Show available commands
default:
  @just --list

# Update system configuration and commit changes
update:
  nh os switch -u "{{flake}}" && nix develop --command "git add . && git commit -m update"
  just health

# Test configuration without switching
test:
  nh os test "{{flake}}"
  nix flake check "{{flake}}"
  just health

# Build configuration
build:
  nh os build "{{flake}}"

# Format Nix files
fmt:
  nixpkgs-fmt "{{flake}}"

# Clean old generations (keep 3)
clean:
  ssh am nh clean all --keep 3
  ssh torag nh clean all --keep 3

# Garbage collect Nix store
gc:
  nix-collect-garbage -d

# Check system health
health:
  systemctl --failed
  journalctl -p 3 -xb --no-pager -n 10 || echo "No recent critical errors"
  df -h /
  check-syncthing

# Clear failed systemd states to stop repeated notifications
clear-notos:
  systemctl --user reset-failed
  systemctl reset-failed

# Check neovim health (shows errors only)
vim-health:
  @nvim --headless -c "checkhealth" -c "w! /tmp/nvim-health.txt" -c "qa" 2>/dev/null || true
  @echo "=== Neovim Checkhealth Summary ==="
  @grep -E '^- (❌|⚠)' /tmp/nvim-health.txt | grep -v 'is not executable. Configuration will not be used' || echo "No errors or warnings found"

# edit the secrets file
secrets:
  mkdir -p ~/.config/sops/age
  ssh-to-age -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt
  sops edit ./modules/nixos/secrets.yaml

# Test remote build infrastructure (am <-> torag)
test-remote-builds:
  test-remote-builds

deploy:
  nixpkgs-fmt "{{flake}}"
  nh os build "{{flake}}" -H am
  nix flake check "{{flake}}"
  nixos-rebuild --flake "{{flake}}#am" --target-host bbrian@am --sudo switch
  ssh torag nh os switch 'git+ssh://am/home/bbrian/conf#torag'


gnome-check:
  got-gnomed
