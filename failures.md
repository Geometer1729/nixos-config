# Known Health Check Failures (baseline 2026-04-08, nixpkgs 68d8aa3d)

## am (primary desktop)

### `just health`
- **obexd**: `stat(/home/bbrian/phonebook/): No such file or directory` — bluetooth phonebook directory doesn't exist, cosmetic
- **kvm_amd**: `SVM not supported by CPU 23` — hardware doesn't support nested virtualization
- **Bluetooth RTL**: `hci1: RTL: RTL: Read reg16 failed (-110)` — hardware/firmware issue, harmless
- **Taskwarrior sync**: intermittent failure on activation (also seen on am now, not just torag)

### `just vim-health`
- **ERROR**: `tree-sitter-cli v0.26.1 is required` — nixpkgs has tree-sitter 0.25.10, neovim 0.12.0 wants 0.26.1. Upstream version lag.
- **WARNING**: `Nvim 0.12.1 is available (current: 0.12.0)` — informational, upstream has newer version
- **WARNING**: `node/npm not in PATH` — no Node.js provider configured
- **WARNING**: `perl not installed` — no Perl provider configured
- **WARNING**: `No Python executable found` — nvim-host-python3 removed from nixpkgs neovim wrapper (nixpkgs>=2026-03-24)
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
