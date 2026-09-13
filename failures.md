# Known Warnings And Check Failures

Verification is scoped to each section; a partial refresh does not update the
baseline for unchecked hosts or commands.

## Evaluation warnings

Verified 2026-09-13 with full `nix flake check /home/bbrian/Code/conf-update-09-12-26`
(nixpkgs 21a67dc). Evaluation and check builds passed on x86_64-linux; these two warnings remain:

- **Custom flake output**: `unknown flake output 'nixos-unified'` — an intentional framework output whose schema Nix's checker does not recognize. No configuration change is needed.
- **Omitted systems**: `The check omitted these incompatible systems: aarch64-darwin, aarch64-linux, x86_64-darwin` — the framework advertises four platforms by default. Decide whether to narrow the supported systems to x86_64-linux or validate the other platforms with `--all-systems`.

## Flake checks

- **Passed, 2026-09-13**: full `nix flake check /home/bbrian/Code/conf-update-09-12-26` passed after Torag's boot-retention change and the final remote-check skill/permission correction, including pre-commit, Neovim configuration, OpenCode plugin type/load checks, and am/balrog/torag system builds. Installer configuration evaluated; its ISO was not rebuilt in this update. Other advertised systems were omitted as noted above.

## installer

### Build and activation
- **Pre-update ISO build passed, 2026-09-12 (nixpkgs 6713828)**: `nix build .#nixosConfigurations.installer.config.system.build.isoImage --no-link --no-write-lock-file --print-out-paths` built the installation image with `boot.zfs.forceImportRoot = false`. The image has not been boot-tested. With updated nixpkgs 21a67dc, only configuration evaluation was checked; the updated ISO build remains unverified.

## am (primary desktop)

### Build and activation
- **Passed, 2026-09-13**: final `nh os build /home/bbrian/Code/conf-update-09-12-26`, `nh os test /home/bbrian/Code/conf-update-09-12-26 --no-nom --show-activation-logs`, and `just deploy` built, activated, and selected system `1j5zkvn…` (nixpkgs 21a67dc, V2-only, corrected remote-check skill/permissions). Running kernel remains 6.18.49 pending desktop reboot.
- **Foundry startup-health race, newly recorded**: Podman's transient `<container-id>-<suffix>.service` runs `healthcheck run` immediately after starting Foundry, returns 1 while health is `starting`, and can make NixOS activation exit 4. Observed on update activations and a concurrent old-input activation. The container becomes healthy and the failed state clears on later probes without intervention; final steady-state activation passed. Follow up on startup/readiness handling rather than disabling the health check.
- **PrismLauncher compiler warnings, newly recorded**: local builds warn that Java source/target 7 and Applet/AppletStub APIs are obsolete. The build succeeds; these belong to upstream legacy-Minecraft launcher support. Track upstream's compatibility/compiler migration rather than removing that support locally.
- **System-path collisions, newly recorded**: `pkgs.buildEnv` ignores duplicate PostgreSQL 18.6 `bin/postgres` and Xwayland/Xorg `protocol.txt` / `Xserver.1.gz`. The PostgreSQL service explicitly uses `postgresql-and-plugins` and is active; the global CLI selects the base package. X-server collisions concern documentation. Review duplicate package exposure if these warnings are to be eliminated.
- **Info-index warning, newly recorded**: `install-info` reports no directory entry in `gawknotes.info`. Build succeeds; the supplemental document lacks index metadata. Follow upstream packaging if an index entry is needed.

### `just health`
Checked 2026-09-13 on system `1j5zkvn…` (nixpkgs 21a67dc): no failed system units; Syncthing reports two peers connected. The journal slice matches the duplicate D-Bus/menu warnings below. Earlier intermittent boot/hardware findings are retained because their original conditions were not re-exercised.

- **obexd**: `stat(/home/bbrian/phonebook/): No such file or directory` — bluetooth phonebook directory doesn't exist, cosmetic
- **kvm_amd**: `SVM not supported by CPU 23` — hardware doesn't support nested virtualization
- **Bluetooth RTL**: `hci1: RTL: RTL: Read reg16 failed (-110)` — hardware/firmware issue, harmless
- **ACPI USB _PLD**: `AE_AML_UNINITIALIZED_ELEMENT` for `PTXH.RHUB.POT7._PLD` — firmware ACPI table issue surfaced in the boot journal
- **dbus-broker duplicate service names**: duplicate names for Blueman, dconf, accessibility, and xdg-desktop-portal service files after boot/activation — noisy but services are still running
- **plasma-apply-lookandfeel**: `"applications.menu" not found` during Home Manager activation — one-shot menu lookup noise; activation still succeeds
- **FoundryVTT auth DNS**: `getaddrinfo EAI_AGAIN foundryvtt.com` during boot/authentication — transient DNS/network timing unless it persists
- **Bluetooth HFP SDP**: `Unable to get Hands-Free Voice gateway SDP record: Host is down` — Bluetooth device/service availability noise
- **Filesystem capacity, newly recorded 2026-09-12**: `/` is 96% used, with about 36 GiB available. No space-related check failure occurred; review capacity before substantially larger builds. No cleanup was performed by the update.

### `just vim-health`
Rechecked 2026-09-13 on system `1j5zkvn…` (nixpkgs 21a67dc); the following existing warnings remain.

- **WARNING**: render-markdown LaTeX helpers `utftex` and `latex2text` are absent
- **WARNING**: Neovim 0.12.5 is available while the configured nixpkgs package is 0.12.4
- **WARNING**: `yaml.docker-compose`, `yaml.gitlab`, and `yaml.helm-values` unknown filetypes — upstream LSP config advertises filetypes not known to this Neovim runtime
- **WARNING**: `biber is not executable!` — LaTeX bibliography tool, not installed globally (vimtex plugin check)

### `just gnome-check`
- Clean on 2026-09-13: `just gnome-check` found no GNOME packages on system `1j5zkvn…` (nixpkgs 21a67dc).

## balrog

### Build and activation
- **Passed, 2026-09-13**: final `just deploy`, run from `/home/bbrian/Code/conf-update-09-12-26`, activated expected system `k21qggj…` (nixpkgs 21a67dc, final skill/permissions). Active and default system verified.

### Post-deployment boot checks
- **Passed, 2026-09-13 at 07:53 EDT**: after confirming final expected system `k21qggj…`, `ssh balrog sudo -n systemctl reboot` succeeded. A changed boot ID, expected active system, Linux 6.18.50, `systemctl is-system-running --wait` = `running`, and zero failed system units were verified after boot.

## torag (secondary machine)

### Build and activation
- **Passed, 2026-09-13**: direct update-worktree `nh os test` / `nh os switch` recovered deployment, then final `just deploy` activated expected system `qh9nqrp…` (nixpkgs 21a67dc, final skill/permissions). Active/default profile and GRUB default match. Three menu generations (235/234/233), all referenced boot files, and about 279 MiB free in `/boot` were verified after the approved cleanup and retention fix. The initial ENOSPC deployment failure is resolved; recovery evidence is in `update-reports/2026-09-12.md`. Running kernel remains 6.18.49; booting Torag's updated 6.18.50 configuration remains unverified until its next reboot.

### `just health`
Checked 2026-09-13 with `ssh torag just --justfile /home/bbrian/conf/justfile health`, system `qh9nqrp…` (nixpkgs 21a67dc): no failed system units, root filesystem 36% used with 605 GiB available, and two Syncthing peers connected. The recent journal shows the duplicate D-Bus/menu findings below; earlier boot/resume conditions were not re-exercised.

- **ucsi_acpi**: `PPM init failed` — USB Type-C firmware issue, hardware
- **spd5118**: `Failed to write` / `failed to resume async: error -6` — RAM SPD sensor resume error after sleep, hardware
- **D-Bus/menu activation noise, newly recorded on torag**: duplicate accessibility, Blueman, dconf, and portal service names, plus `plasma-apply-lookandfeel` reporting `"applications.menu" not found`. These match am's existing findings; activation succeeds with zero failed units. Review duplicate service exports and the one-shot menu lookup if eliminating the noise.

### `just vim-health`
Rechecked 2026-09-13 with `ssh torag just --justfile /home/bbrian/conf/justfile vim-health`, system `qh9nqrp…` (nixpkgs 21a67dc). The existing warnings remain.

- **WARNING**: render-markdown LaTeX helpers `utftex` and `latex2text` are absent
- **WARNING**: Neovim 0.12.5 is available while the configured nixpkgs package is 0.12.4
- **WARNING**: `yaml.docker-compose`, `yaml.gitlab`, and `yaml.helm-values` unknown filetypes — upstream LSP config advertises filetypes not known to this Neovim runtime
- **WARNING**: `No clipboard tool found` — observed in the SSH-launched headless check; GUI-session clipboard behavior was not exercised
- **WARNING**: `biber is not executable!` — same as am

### `just gnome-check`
- Clean on 2026-09-13: `ssh torag just --justfile /home/bbrian/conf/justfile gnome-check` found no GNOME packages on system `qh9nqrp…` (nixpkgs 21a67dc).

## Remote builds (`just test-remote-builds`)
- Passed from am on 2026-09-13, system `1j5zkvn…` (nixpkgs 21a67dc): both client SSH connections, fresh balrog/torag builds on am, six HTTP-cache reachability checks, two locally built signed paths, and four signature-verified cache transfers passed (16 assertions). The final Torag invocation, `ssh torag just --justfile /home/bbrian/conf/justfile test-remote-builds` on system `qh9nqrp…`, also passed all 16 assertions.

## Update tooling

Newly recorded 2026-09-12 during the update; recovered coverage and raw evidence are documented in `update-reports/2026-09-12.md`.

- **Suppressed package-extraction errors**: `nixpkgs-changelog` silently continued after the Linearis version assertion prevented Home Manager evaluation (231 rather than 408 package names). Fix individual evaluation error reporting and inventory coverage; the current extractor omits some profiles and option-injected dependencies. The update repaired the pin and reviewed the complete commit range independently.
- **Regex package false positives**: `[26.05]` was passed unescaped to `grep`, producing an unrelated `jwx` match. Use literal package matching; this false positive was rejected by configuration/source review.
- **Missing non-Git inputs**: `flake-changelog` compares only `.rev`, omitting changed `linearis-npm` registry metadata. Compare locked content for file inputs and report their non-Git identity. The final artifact has an explicitly labeled manual entry and complete direct-input accounting.
