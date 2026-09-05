# Known Health Check Failures (baseline updated 2026-09-04, nixpkgs a5cc6f2)

## am (primary desktop)

### `just health`
- **obexd**: `stat(/home/bbrian/phonebook/): No such file or directory` — bluetooth phonebook directory doesn't exist, cosmetic
- **kvm_amd**: `SVM not supported by CPU 23` — hardware doesn't support nested virtualization
- **Bluetooth RTL**: `hci1: RTL: RTL: Read reg16 failed (-110)` — hardware/firmware issue, harmless
- **ACPI USB _PLD**: `AE_AML_UNINITIALIZED_ELEMENT` for `PTXH.RHUB.POT7._PLD` — firmware ACPI table issue surfaced in the boot journal
- **Waybar**: `.waybar-wrapped` coredump seen after activation — likely activation/session restart related unless it repeats during normal use
- **Syncthing**: peer `3MB5CXC` disconnected — likely torag/offline peer state
- **Taskwarrior sync**: intermittent failure on activation (also seen on am now, not just torag)
- **dbus-broker duplicate service names**: duplicate names for Blueman, dconf, and xdg-desktop-portal service files after boot — noisy but services are still running
- **plasma-apply-lookandfeel**: `"applications.menu" not found` during Home Manager activation — one-shot menu lookup noise; activation still succeeds
- **FoundryVTT auth DNS**: `getaddrinfo EAI_AGAIN foundryvtt.com` during boot/authentication — transient DNS/network timing unless it persists
- **Bluetooth HFP SDP**: `Unable to get Hands-Free Voice gateway SDP record: Host is down` — Bluetooth device/service availability noise

### `just vim-health`
- **WARNING**: auto-session recommends `localoptions` in `sessionoptions`, despite reporting the recommended value as the current value
- **ERROR**: Nix-managed nvim-treesitter parser directory is not writable or in `runtimepath` — parser grammars are supplied from the Nix store and render-markdown confirms they load
- **WARNING**: render-markdown LaTeX helpers `utftex` and `latex2text` are absent
- **WARNING**: Neovim 0.12.5 is available while the configured nixpkgs package is 0.12.4
- **ERROR**: headless check inherits `TERM=xterm-256color` inside tmux while tmux uses a different `default-terminal`
- **WARNING**: LSP log size is large — stale local Neovim state, not config evaluation
- **WARNING**: `yaml.docker-compose`, `yaml.gitlab`, and `yaml.helm-values` unknown filetypes — upstream LSP config advertises filetypes not known to this Neovim runtime
- **WARNING**: `biber is not executable!` — LaTeX bibliography tool, not installed globally (vimtex plugin check)

### `just gnome-check`
- Clean

## torag (secondary machine)

### `just health`
- **dhcpcd**: `no valid interfaces found` / `No such file or directory` for config — expected, torag uses networkmanager not dhcpcd
- **ucsi_acpi**: `PPM init failed` — USB Type-C firmware issue, hardware
- **spd5118**: `Failed to write` / `failed to resume async: error -6` — RAM SPD sensor resume error after sleep, hardware
- **Taskwarrior sync**: intermittent failure, typically after wake from sleep

### `just vim-health`
- **WARNING**: auto-session recommends `localoptions` in `sessionoptions`, despite reporting the recommended value as the current value
- **ERROR**: Nix-managed nvim-treesitter parser directory is not in `runtimepath` — parser grammars are supplied from the Nix store and render-markdown confirms they load
- **WARNING**: render-markdown LaTeX helpers `utftex` and `latex2text` are absent
- **WARNING**: Neovim 0.12.5 is available while the configured nixpkgs package is 0.12.4
- **WARNING**: `yaml.docker-compose`, `yaml.gitlab`, and `yaml.helm-values` unknown filetypes — upstream LSP config advertises filetypes not known to this Neovim runtime
- **WARNING**: `No clipboard tool found` — expected on headless/no-desktop torag
- **WARNING**: `biber is not executable!` — same as am

### `just gnome-check`
- Clean

## Remote builds (`just test-remote-builds`)
- All 6 tests passing
