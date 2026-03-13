# Known Health Check Failures (baseline 2026-03-12, nixpkgs 62dc67aa)

## am (primary desktop)

### `just health`
- **ACPI Error**: `\_SB.PCI0.GPP2.PTXH.RHUB.POT9._PLD` AE_AML_UNINITIALIZED_ELEMENT — hardware/firmware bug on USB controller, harmless
- **obexd**: `stat(/home/bbrian/phonebook/): No such file or directory` — bluetooth phonebook directory doesn't exist, cosmetic
- **pre-shutdown.service**: `Service has no ExecStart=, ExecStop=, or SuccessAction=. Refusing.` — empty service unit, cosmetic

### `just vim-health`
- **ERROR**: `tree-sitter-cli v0.26.1 is required` — nixpkgs has tree-sitter 0.25.10, neovim 0.11.6 wants 0.26.1. Upstream version lag.
- **WARNING**: `biber is not executable!` — LaTeX bibliography tool, not installed globally (vimtex plugin check)
- **WARNING**: LSP servers not executable (haskell-language-server, purescript-language-server, rust-analyzer, typescript-language-server) — these are project-specific, loaded via direnv. Expected when running headless outside a project.

### `just gnome-check`
- Clean

## torag (secondary machine)

### `just health`
- **dhcpcd**: `no valid interfaces found` / `No such file or directory` for config — expected, torag uses networkmanager not dhcpcd
- **ucsi_acpi**: `PPM init failed` — USB Type-C firmware issue, hardware
- **spd5118**: `Failed to write` / `failed to resume async: error -6` — RAM SPD sensor resume error after sleep, hardware
- **pre-sleep.service / pre-shutdown.service**: `Service has no ExecStart=` — empty service units, cosmetic (same as am)
- **Taskwarrior sync**: intermittent failure, typically after wake from sleep

### `just vim-health`
- **ERROR**: `tree-sitter-cli v0.26.1 is required` — same as am
- **ERROR**: `is not in runtimepath.` — unclear what this refers to, present since at least this baseline
- **WARNING**: `No clipboard tool found` — expected on headless/no-desktop torag
- **WARNING**: `biber is not executable!` — same as am
- **WARNING**: LSP servers not executable (haskell-language-server, lua-language-server, purescript-language-server, rust-analyzer, typescript-language-server) — same as am, plus lua-language-server since torag doesn't have it in system packages

### `just gnome-check`
- Clean

## Remote builds (`just test-remote-builds`)
- All 6 tests passing
