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
  ssh am nh clean all --keep 3 --optimise
  ssh torag nh clean all --keep 3 --optimise
  ssh balrog nh clean all --keep 3 --optimise

# Garbage collect Nix store
gc:
  nix-collect-garbage -d

# Stop a machine suspending (default: torag for 24h; `just awake torag off` cancels)
awake host="torag" duration="24h":
  ssh {{host}} keep-awake {{duration}}

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
  @if [ "${OPENCODE_TERMINAL:-}" = 1 ] && [ -n "${TMUX:-}" ]; then export TERM="$(tmux show-options -gv default-terminal)"; fi; nvim --headless -c "checkhealth" -c "w! /tmp/nvim-health.txt" -c "qa" 2>/dev/null || true
  @echo "=== Neovim Checkhealth Summary ==="
  @grep -E '^- (❌|⚠)' /tmp/nvim-health.txt | grep -v 'is not executable. Configuration will not be used' || echo "No errors or warnings found"

# edit the secrets file
secrets:
  mkdir -p ~/.config/sops/age
  ssh-to-age -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt
  sops edit ./modules/nixos/secrets/secrets.yaml

# Test remote build infrastructure (am <-> torag)
test-remote-builds:
  test-remote-builds

# Build once and retain the config devshell on both development machines
deploy-devshell:
  #!/usr/bin/env bash
  set -euo pipefail
  # Keep the root outside .direnv and avoid result* names, which nh clean removes.
  shell=$(nix build "{{flake}}#devShells.x86_64-linux.default" --out-link "{{flake}}/.deploy-devshell" --print-out-paths)
  for host in am torag; do
    nix copy --substitute-on-destination --to "ssh://bbrian@$host" "$shell"
    ssh "bbrian@$host" nix-store --realise "$shell" --add-root /home/bbrian/conf/.deploy-devshell
  done

deploy:
  #!/usr/bin/env bash
  set -euo pipefail
  nixpkgs-fmt "{{flake}}"
  nix flake check "{{flake}}"
  just deploy-devshell
  for host in am balrog torag; do
    extra_args=()
    if [[ "$host" != am ]]; then
      extra_args+=(--use-substitutes)
    fi
    nh os switch "{{flake}}" -H "$host" --target-host "bbrian@$host" --elevation-strategy passwordless "${extra_args[@]}"
  done


gnome-check:
  got-gnomed
