# Show available commands
default:
  @just --list

# Update system configuration and commit changes
update:
  nh os switch -u && nix develop --command "git add . && git commit -m update"
  just health

# Test configuration without switching
test:
  nh os test
  nix flake check
  just health

# Build configuration
build:
  nh os build

# Format Nix files
fmt:
  nixpkgs-fmt .

# Clean old generations (keep 3)
clean:
  nh clean all --keep 3

# Garbage collect Nix store
gc:
  nix-collect-garbage -d

# Check system health
health:
  systemctl --failed
  journalctl -p 3 -xb --no-pager -n 10 || echo "No recent critical errors"
  df -h /

# edit the secrets file
secrets:
  ssh-to-age -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt
  sops edit ./modules/nixos/secrets.yaml
