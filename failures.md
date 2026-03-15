# Known Health Check Failures (baseline 2026-03-15, nixpkgs c06b4ae3)

## am (primary desktop)

### `just health`
- **ACPI Error**: `\_SB.PCI0.GPP2.PTXH.RHUB.POT7._PLD` AE_AML_UNINITIALIZED_ELEMENT — hardware/firmware bug on USB controller, harmless
- **obexd**: `stat(/home/bbrian/phonebook/): No such file or directory` — bluetooth phonebook directory doesn't exist, cosmetic

### `just vim-health`
- **ERROR**: `tree-sitter-cli v0.26.1 is required` — nixpkgs has tree-sitter 0.25.10, neovim 0.11.6 wants 0.26.1. Upstream version lag.
- **ERROR**: `is not in runtimepath.` — appeared after neovim provider rework (was previously only on torag)
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
