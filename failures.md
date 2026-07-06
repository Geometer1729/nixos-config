# Known Health Check Failures (baseline 2026-04-08, nixpkgs 68d8aa3d)

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
- **FoundryVTT auth DNS**: `getaddrinfo EAI_AGAIN foundryvtt.com` during boot/authentication — transient DNS/network timing unless it persists
- **Bluetooth HFP SDP**: `Unable to get Hands-Free Voice gateway SDP record: Host is down` — Bluetooth device/service availability noise

### `just vim-health`
- **ERROR**: nvim-treesitter install directory `/home/bbrian/.local/share/nvim/site` is writable but not in runtimepath — packaged parsers are still available from the Nix store
- **WARNING**: LSP log size is large — stale local Neovim state, not config evaluation
- **WARNING**: Nvim 0.12.4 is available while packaged Nvim is 0.12.3 — upstream availability notice (version pair drifts with each update)
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
- **ERROR**: `tree-sitter-cli v0.26.1 is required` — same as am
- **WARNING**: `No clipboard tool found` — expected on headless/no-desktop torag
- **WARNING**: `biber is not executable!` — same as am

### `just gnome-check`
- Clean

## Remote builds (`just test-remote-builds`)
- All 6 tests passing
