# Known Warnings And Check Failures

Verification is scoped to each section; a partial refresh does not update the
baseline for unchecked hosts or commands.

## Evaluation warnings

Verified 2026-09-12 with `nix flake check --no-build --no-write-lock-file`
(nixpkgs 6713828). Evaluation passed on x86_64-linux; these three warnings remain:

- **Installer ZFS default**: `boot.zfs.forceImportRoot` defaults to `true` — the installer enables ZFS support, but uses a tmpfs root; am, balrog, and torag use Btrfs with ZFS support disabled. Set `boot.zfs.forceImportRoot = false` explicitly in `configurations/nixos/installer/default.nix`.
- **Custom flake output**: `unknown flake output 'nixos-unified'` — an intentional framework output whose schema Nix's checker does not recognize. No configuration change is needed.
- **Omitted systems**: `The check omitted these incompatible systems: aarch64-darwin, aarch64-linux, x86_64-darwin` — the framework advertises four platforms by default. Decide whether to narrow the supported systems to x86_64-linux or validate the other platforms with `--all-systems`.

## Flake checks

- **Evaluation-only pass, 2026-09-12**: `nix flake check --no-build --no-write-lock-file` evaluated the x86_64-linux checks and NixOS configurations successfully. Full check builds were not run in this pass; their status is unverified.

## am (primary desktop)

### Build and activation
- **Passed, 2026-09-12**: `NIX_SUDOOPTS=-n nixos-rebuild test --flake .#am --sudo --no-write-lock-file` built and activated the configuration successfully.

### `just health`
Baseline last updated 2026-09-05 (nixpkgs a5cc6f2); not rechecked in this pass.

- **obexd**: `stat(/home/bbrian/phonebook/): No such file or directory` — bluetooth phonebook directory doesn't exist, cosmetic
- **kvm_amd**: `SVM not supported by CPU 23` — hardware doesn't support nested virtualization
- **Bluetooth RTL**: `hci1: RTL: RTL: Read reg16 failed (-110)` — hardware/firmware issue, harmless
- **ACPI USB _PLD**: `AE_AML_UNINITIALIZED_ELEMENT` for `PTXH.RHUB.POT7._PLD` — firmware ACPI table issue surfaced in the boot journal
- **dbus-broker duplicate service names**: duplicate names for Blueman, dconf, and xdg-desktop-portal service files after boot — noisy but services are still running
- **plasma-apply-lookandfeel**: `"applications.menu" not found` during Home Manager activation — one-shot menu lookup noise; activation still succeeds
- **FoundryVTT auth DNS**: `getaddrinfo EAI_AGAIN foundryvtt.com` during boot/authentication — transient DNS/network timing unless it persists
- **Bluetooth HFP SDP**: `Unable to get Hands-Free Voice gateway SDP record: Host is down` — Bluetooth device/service availability noise

### `just vim-health`
Baseline last updated 2026-09-05 (nixpkgs a5cc6f2); not rechecked in this pass.

- **WARNING**: render-markdown LaTeX helpers `utftex` and `latex2text` are absent
- **WARNING**: Neovim 0.12.5 is available while the configured nixpkgs package is 0.12.4
- **WARNING**: `yaml.docker-compose`, `yaml.gitlab`, and `yaml.helm-values` unknown filetypes — upstream LSP config advertises filetypes not known to this Neovim runtime
- **WARNING**: `biber is not executable!` — LaTeX bibliography tool, not installed globally (vimtex plugin check)

### `just gnome-check`
- Clean as of the 2026-09-05 baseline (nixpkgs a5cc6f2); not rechecked in this pass.

## balrog

### Build and activation
- Unverified in this pass; flake evaluation does not establish remote activation success.

### Post-deployment boot checks
- Unverified in this pass; no reboot, running-kernel comparison, or post-boot `systemctl --failed` check was performed.

## torag (secondary machine)

### Build and activation
- Unverified in this pass; flake evaluation does not establish remote activation success.

### `just health`
Baseline last updated 2026-09-05 (nixpkgs a5cc6f2); not rechecked in this pass.

- **ucsi_acpi**: `PPM init failed` — USB Type-C firmware issue, hardware
- **spd5118**: `Failed to write` / `failed to resume async: error -6` — RAM SPD sensor resume error after sleep, hardware

### `just vim-health`
Baseline last updated 2026-09-05 (nixpkgs a5cc6f2); not rechecked in this pass.

- **WARNING**: render-markdown LaTeX helpers `utftex` and `latex2text` are absent
- **WARNING**: Neovim 0.12.5 is available while the configured nixpkgs package is 0.12.4
- **WARNING**: `yaml.docker-compose`, `yaml.gitlab`, and `yaml.helm-values` unknown filetypes — upstream LSP config advertises filetypes not known to this Neovim runtime
- **WARNING**: `No clipboard tool found` — expected on headless/no-desktop torag
- **WARNING**: `biber is not executable!` — same as am

### `just gnome-check`
- Clean as of the 2026-09-05 baseline (nixpkgs a5cc6f2); not rechecked in this pass.

## Remote builds (`just test-remote-builds`)
- All 6 tests passed in the 2026-09-05 baseline (nixpkgs a5cc6f2); the initiating host was not recorded. Neither am nor torag was rechecked in this pass.
