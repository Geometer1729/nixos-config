# Known Warnings And Check Failures

Verification is scoped to each section; a partial refresh does not update the
baseline for unchecked hosts or commands.

## Evaluation warnings

This section is only for evaluation warnings in `nix flake check` or `nix build *` for this repo.

Verified 2026-10-17 with full `nix flake check -L` and `nh os build` (update worktree,
nixpkgs 26f4107). Evaluation and check builds passed on x86_64-linux; the following findings remain:

- **Custom flake output**: `unknown flake output 'nixos-unified'` — an intentional framework output whose schema Nix's checker does not recognize. No configuration change is needed.
- **Omitted systems**: `The check omitted these incompatible systems: aarch64-darwin, aarch64-linux, x86_64-darwin` — the framework advertises four platforms by default. Decide whether to narrow the supported systems to x86_64-linux or validate the other platforms with `--all-systems`.

- **Nix database contention during concurrent evaluations**: the 2026-09-20 flake check warned `SQLite database '/nix/var/nix/db/db.sqlite' is busy`; the September 14 plugin checks reported the analogous warning for `…/.cache/nix/eval-cache-v6/….sqlite`. Both runs ultimately passed; the final update checks emitted only the two warnings above. Recheck if contention recurs without concurrent evaluations; no database repair or deletion was needed.

- **Cold eval-only source-store failure, newly recorded 2026-09-23**: Nix 2.35.2 `nix flake check --no-build` failed before output evaluation with `path '/nix/store/<hash>-<hash>-source' is not valid`; `--refresh` also failed. Direct builds and flake metadata passed. Full `nix flake check -L` materialized the missing path, after which eval-only checking passed too. Investigate read-only flake source materialization; no Nix fix was applied. Evidence: `/tmp/opencode/waybar-modes-eval{,-final,-after-full-check}.log` and `waybar-modes-checks.log`.

## Flake checks

- **Passed, 2026-10-17**: full `nix flake check -L` (nixpkgs 26f4107), including all three host builds and the OpenCode plugin load/reload check. ISO build/boot and other advertised platforms remain unverified.
- **Plugin-check npm warnings, newly recorded 2026-09-21**: `opencode-plugins-check` reports unknown environment config `nodedir` and deprecated transitive `node-domexception@1.0.0`, `glob@9.3.5`, and `glob@10.5.0`. Since 2026-10-03 it also reports `EBADENGINE`: `@opentui/core` (0.5.17 since 2026-10-17, `@opencode/plugin` 2.0.32) requires `node >=26.4.0` / `bun >=1.3.0`, but the check runs Node 24.21.0. Typecheck and all 47 tests pass; OpenCode loads plugins under its bundled Bun at runtime. Move the check to a satisfying runtime if Node-specific failures appear; otherwise follow the npm hook and dependency updates rather than suppressing the warnings.

## installer

### Build and activation
- **ISO build passed, 2026-09-12 (nixpkgs 6713828)**; never boot-tested. On 2026-09-20, updated nixpkgs cf9d2fb passed configuration evaluation only; the updated ISO build/boot remains unverified.

## durin (primary desktop, formerly am)

### Build and activation
- **Passed, 2026-10-17**: `nh os build`, then a detached `sudo systemd-run --collect <system>/bin/switch-to-configuration test` (see "Activation killed with its calling session") and `just deploy boot`; active/default `d7hnfawm…` (nixpkgs 26f4107), no failed system or user units. Not yet rebooted into Linux 6.18.56.
- **PrismLauncher build warnings**: Java source/target 7 and Applet APIs are obsolete, and CMake reports unused `CMAKE_EXPORT_NO_PACKAGE_REGISTRY`; both remain in the 2026-10-03 12.0-develop build. The Qt AutoUic duplicate-`verticalLayout` warning is resolved upstream (`c2ef89ec`) and absent from that build. Build/tests pass; track upstream compiler packaging rather than removing legacy support.
- **PrismLauncher intermittent check timeout, newly recorded 2026-09-20**: `ResourceFolderModelTest::test_removeResource()` line 161 expires its 10-second timer during the initial fixture installation, causing checkPhase exit 8. The test and affected path are unchanged; upstream PR #5912 documents prior timing failures. The same derivation passed all 22 tests on retry, and the 2026-10-03 build passed 23/23 on its first attempt; the intermittent condition was not re-exercised. Exact delay cause is unknown; retain a disposable build tree for isolated/full-class reproduction before proposing a fix. No tests were disabled.
- **Initrd alternate-library warnings, newly recorded 2026-09-20**: `Couldn't satisfy dependency libcrypt.so.1` / `.so.1.1`, unchanged with systemd 260.5 (2026-10-17). The initrd builder checks each dlopen SONAME alternative separately. The actual old am and all three new host initrds contain byte-identical `libcrypt.so.2`; no missing password-hashing implementation was found. No workaround needed; follow upstream warning handling. Balrog's 6.18.54 initrd also passed its 2026-10-03 reboot check below.
- **System-path collisions, newly recorded**: `pkgs.buildEnv` ignores duplicate PostgreSQL 18.6 `bin/postgres` and Xwayland/Xorg `protocol.txt` / `Xserver.1.gz`. The PostgreSQL service explicitly uses `postgresql-and-plugins` and is active; the global CLI selects the base package. X-server collisions concern documentation. Review duplicate package exposure if these warnings are to be eliminated.
- **Info-index warning, newly recorded**: `install-info` reports no directory entry in `gawknotes.info`. Build succeeds; the supplemental document lacks index metadata. Follow upstream packaging if an index entry is needed.
- **Upstream derivation build-log noise, newly recorded 2026-10-03**: derivations built locally rather than substituted print their own deprecation warnings. Examples: setuptools license-classifier/`setup.py install` deprecations (vit, tasklib, ranger, nixos-render-docs); ImageMagick 7 `convert` deprecation (nixos-icons, stylix-grub); `Fontconfig error: No writable cache directories` (nerd-fonts); GSettings `/system/` schema-path deprecations (steam FHS rootfs); Discord's declared `autoPatchelfIgnoreMissingDeps` for `libcrypto.so.1.1`; and C++/libxml2 deprecations in Inkscape/gtksourceview during flake check. All builds succeed. These come from upstream package builds, not from this configuration; no action unless one becomes an error.

### Desktop runtime
- **RCU Tasks shutdown stalls, newly recorded 2026-10-09**: intermittent `rcu_tasks_wait_gp` warnings since July 30; October 9 shutdown paused 120.5s between PID 1's `Shutting down.` and the shutdown hand-off on Linux 6.18.54. The blocking task and cause are unconfirmed. `rcupdate.rcu_task_stall_timeout=15000` enables task/stack reports after 15s at HZ=1000; verified live on October 9. Inspect `journalctl -b -1 -k` after the next affected shutdown; the stall has not been re-exercised.
- **KDE portal host-registration warning, newly recorded 2026-09-29**: after restoring discovery of the KDE backend, its startup reports `Failed to register with host portal` / `Connection already associated with an application ID`. The portal starts, `OpenDirectory` accepts the previously failing request, and Brian confirmed Brave's folder button works. The duplicate association's cause is unverified; inspect the KDE/host-portal registration sequence before changing registration behavior.
- **fwupd refresh resume race, newly recorded 2026-09-27**: on September 26 at 21:44:50 EDT, `fwupd-refresh.service` exited 1 with `Could not resolve host: cdn.fwupd.org` after its timer fired on resume; DHCP restored IPv4 at 21:44:54. A 30-second failure retry with five starts per ten minutes is active on am; loaded settings and a real metadata download passed September 27 at 08:37:56 EDT. Recovery through a retry after suspend remains unverified; check the next affected resume. Upstream success statuses `2 101` remain exempt from retries. Torag's shared policy was evaluated only.
- **Terminal snapshot loss on shutdown, patched 2026-09-20**: tmux pane scopes stopped during the logout save (`no server running`); tmux-resurrect promoted an incomplete snapshot, causing the next boot's terminal-restore timeout. Scope ordering now holds panes and Ghostty-hosted servers until saving finishes. `just test-tmux-shutdown` reproduced early teardown before the fix and passed afterward on am. End-to-end reboots on am (2026-10-03 23:05 and 2026-10-04 10:36) restored complete snapshots; Torag's end-to-end reboot remains unverified. Snapshot publication still lacks validation for other save failures.
- **Terminal window not reopened at boot, newly recorded 2026-10-03**: at the 23:06 boot, `restore-terminals` finished successfully but no Ghostty window appeared for the manifest's only session; the same `hyprctl dispatch exec` worked when re-run later. The cause is unknown. Since 2026-10-04 the script logs each dispatch, confirms that a client attached, retries up to three times, and fails the unit if none attaches. The 2026-10-04 10:36 boot attached on attempt 1. Check the `restore-terminals` journal if a window is missing again.
- **Terminal restore blocked by a stale manifest, newly recorded 2026-10-14**: at the October 9 15:53 boot, `restore-terminals` timed out (`Timed out waiting for tmux-resurrect to restore terminal sessions`) and opened no windows. `terminals.json` listed `brian-cor-81-detailed-timeline`, which had ended before the 15:49:51 logout snapshot; the logout manifest save likely ran after Hyprland stopped and kept the 15:44 manifest (unconfirmed). Since 2026-10-14 restore waits only for manifest sessions present in the resurrect snapshot, logs the rest as skipped, and still attaches restored sessions after a timeout. A manual run with a missing session skipped it and exited 0; not yet reboot-tested.
- **Waybar aborts when PipeWire restarts, newly recorded 2026-10-03**: whenever activation stops or restarts PipeWire, waybar's PulseAudio module throws `pa_context_connect() failed: OK` (`std::runtime_error`, SIGABRT, core dumped). On am this happened at 13:23, 22:14 and 22:47 EDT; on Torag at 22:57; recurred on durin 2026-10-17 at 10:19:59. The service restarts and is active within seconds; no failed units remain. Make the PulseAudio module survive a server restart (upstream waybar reconnect handling), or order/restart waybar after PipeWire on activation.
- **Waybar minimum height, newly recorded 2026-09-14**: restarting `waybar.service` reports `Requested height: 24 is less than the minimum height: 34 required by the modules` on both monitors; both bars run at 34 px. The same warning appears in September 11–12 logs before the AI usage module. Align the requested height with the existing font/padding, or revisit sizing if a 24 px bar is desired.
- **Hypridle ScreenSaver cookie accounting, newly recorded 2026-09-23**: `No cookie in uninhibit` / `BUG THIS: inhibit locks < 0: -1` appeared after the idle-daemon restart. The same warnings occur on September 20 and 22, before the workload observer. Subsequent Brave Video Wake Lock acquire/release messages return the count to 1/0. Inspect Hypridle's cookie handling across client/daemon restarts; locking behavior during an unmatched release remains unverified.

### `health`
Checked 2026-10-17 at 10:30 EDT with `nix develop W -c health` on `kaszzsns…` (nixpkgs 26f4107, before reboot): no failed system or user units, root 81% used / 167 GiB available, two Syncthing peers, and the `kvm_amd` activation message below. Earlier intermittent boot/hardware conditions were not re-exercised.

- **obexd**: `stat(/home/bbrian/phonebook/): No such file or directory` — bluetooth phonebook directory doesn't exist, cosmetic
- **kvm_amd**: `SVM not supported by CPU <n>` — hardware doesn't support nested virtualization. When activation restarts `systemd-modules-load`, the same cause also logs `Failed to insert module 'kvm_amd': Operation not supported` (2026-10-03).
- **Keep-awake helper restart, newly recorded 2026-10-03**: `systemd-inhibit[…]: 'sleep' terminated by signal TERM` when activation restarts `workload-inhibit.service`. The service came back active; this is the expected stop of its placeholder inhibitor process.
- **Bluetooth RTL**: `hci1: RTL: RTL: Read reg16 failed (-110)` — hardware/firmware issue, harmless. On 2026-10-03 at 23:19 the same adapters also logged `hci1: command 0x0401 tx timeout` / `Resetting usb device` and `hci2: RTL: Failed to generate devcoredump`, about 12 minutes after boot. Bluetooth recovered without failed units; recheck if devices drop.
- **ACPI USB _PLD**: `AE_AML_UNINITIALIZED_ELEMENT` for `PTXH.RHUB.POT7._PLD` — firmware ACPI table issue surfaced in the boot journal
- **dbus-broker duplicate service names**: duplicate names for Blueman, dconf, accessibility, and xdg-desktop-portal service files after boot/activation — noisy but services are still running
- **plasma-apply-lookandfeel**: `"applications.menu" not found` during Home Manager activation — one-shot menu lookup noise; activation still succeeds
- **Bluetooth HFP SDP**: `Unable to get Hands-Free Voice gateway SDP record: Host is down` — Bluetooth device/service availability noise

### `vim-health`
Rechecked 2026-10-17 on system `kaszzsns…` (nixpkgs 26f4107); the following existing warnings remain.

- **WARNING**: render-markdown LaTeX helpers `utftex` and `latex2text` are absent
- **WARNING**: Neovim 0.12.6 is available while the configured nixpkgs package is 0.12.4
- **WARNING**: `yaml.docker-compose`, `yaml.gitlab`, and `yaml.helm-values` unknown filetypes — upstream LSP config advertises filetypes not known to this Neovim runtime
- **WARNING**: `biber is not executable!` — LaTeX bibliography tool, not installed globally (vimtex plugin check)

### `gnome-health`
- Clean on 2026-10-17: `nix develop W -c health`, system `kaszzsns…` (nixpkgs 26f4107).

## narvi (server, formerly balrog)

### Build and activation
- **Passed, 2026-10-17**: `just deploy boot` and a reboot (no live switch, so no session loss), then `deploy switch narvi` for the substituter fix; active/default `6aadmsm…` (nixpkgs 26f4107), `running`, zero failed units.
- **Foundry startup-health race, moved from am**: Podman's transient `<container-id>-<suffix>.service` runs `healthcheck run` immediately after starting Foundry, returns 1 while health is `starting`, and can make NixOS activation exit 4. Reproduced during Balrog's September 26 activation and reboot, the 2026-10-03 completion switch, and the 2026-10-17 reboot (Podman 5.8.8; `degraded` until it cleared within about a minute). Later timer probes cleared the failed state without a reset. Upstream tracks the same failure for all transient units as [nixpkgs #558533](https://github.com/NixOS/nixpkgs/issues/558533). Follow up on startup/readiness handling, or on that fix, rather than disabling the health check.

### FoundryVTT runtime
- **Auth DNS, moved from am**: `getaddrinfo EAI_AGAIN foundryvtt.com` recurred during Balrog's September 26 boot/authentication, at the 2026-10-17 11:25 boot, and at the 2026-10-03 23:04 boot (`Unable to authenticate: request to https://foundryvtt.com/ failed`). Later container DNS lookup passed and Foundry was healthy; investigate startup network readiness if this continues.
- **License-verification startup message, newly recorded 2026-09-26**: `Software license verification failed` appeared on am before migration and Balrog after reboot. The browser initially reached `/license`, then reached `/auth`; the container is healthy. The message's cause is unverified; check licensing if it recurs or blocks world access. This predates the migration.

### `health`
Checked 2026-10-17 at 11:30 EDT with `nix develop W -c health narvi` on `m73il1w…` (nixpkgs 26f4107, after reboot): no failed system or user units, root 34% used / 151 GiB available, two Syncthing peers, and the Foundry auth-DNS boot error above.

- **D-Bus duplicate service names, newly recorded on Balrog**: boot journal reports duplicate dconf and systemd service names, matching the desktop hosts' existing warning class. Review duplicate service exports if eliminating the noise.

### `vim-health`
First checked 2026-10-17 with `health narvi` (headless server):

- **WARNING**: `utftex`/`latex2text` absent, Neovim 0.12.6 available, `yaml.*` unknown filetypes, `biber is not executable!`, and `No clipboard tool found`: same as gimli
- **WARNING**: `vim.ui.open: no handler found (tried: wslview, explorer.exe, xdg-open, lemonade)`: there is no desktop opener on the headless server. Only matters if URLs are opened from Neovim on narvi.

### `gnome-health`
- Clean on 2026-10-17: `health narvi`, system `m73il1w…`.

### Post-deployment boot checks
- **Update reboots passed, 2026-10-17 at 11:24 and 11:44 EDT**: the second reboot (into `6aadmsm…`, boot ID `bf104a42…`) was `running` with zero failed units, and a scratch 3.7b tmux server parsed the config. First reboot: `ssh narvi sudo -n systemctl reboot`; new boot ID `9aa96940…`, Linux 6.18.56, booted/active/default `m73il1w…`; briefly `degraded` from the Foundry healthcheck transient, then `running` with zero failed system and user units; Foundry, nginx, nix-serve, smartd, taskchampion-sync-server and the GitHub runner active.
- **Foundry checks passed, 2026-09-26**: rebooted into expected active/booted/default `c42xf9x…`; original image/version 13.351.0, persistent data/image mounts, data-content checksum comparison, LAN HTTP, and no failed system or user units verified after the startup-health transient cleared.
- **Storage checks passed, 2026-09-21 at 16:59 EDT**: `ssh balrog sudo -n systemctl reboot`; new boot ID, expected active/default `r7v1p7f…`, Linux 6.18.52, zero failed system units, persisted SMART state, unchanged scrub-result hash/timer timestamp, and active monitoring verified. Alert delivery to am also passed after reboot.
- **Secrets/sync boot checks passed, 2026-09-21 at 20:52 EDT**: rebooted into expected active/booted/default `xhsxkk6…`, Linux 6.18.52. Both SOPS steps imported only the persisted user SSH key, expected secrets were readable, automatic Taskwarrior sync succeeded at 20:48 EDT without corrective activation, and system/user failed-unit lists were empty.

### Storage health
- **Unsupported SMART attributes, 2026-09-21**: smartd reports no attributes 197 (`Current_Pending_Sector`) or 198 (`Offline_Uncorrectable`) on the Samsung 860 EVO. `smartctl -a` confirms these are absent from the device's attribute table; supported attributes and overall health are monitored. No suppression or configuration change is needed.

## gimli (laptop, formerly torag)

### Build and activation
- **Passed, 2026-10-17**: `just deploy boot`, then a detached `ssh gimli sudo -n systemd-run --collect <system>/bin/switch-to-configuration switch` (`finished switching`, exit 0); active/default `3wirlf8…` (nixpkgs 26f4107).

### Network
- **Wi-Fi throughput on 2.4 GHz, newly recorded 2026-10-03**: Torag joins `moria` on 2412 MHz / 20 MHz when the router doesn't offer 5 GHz under that SSID. In that state, LAN RTT is 13–510 ms (0.5–1.6 s under load) and SSH throughput ~2 MiB/s. On 5 GHz / 80 MHz it gets ~50 MiB/s. The 5 GHz BSS came and went during the evening; at 22:42 Torag was on 5220 MHz (816 Mbit/s PHY rate) and the deploy copy was fast. The `ssh-ng` substituter that made slow links unbearable was replaced by `http://am:5000?priority=50` (`7bbd75f`). Recheck the band if deploys slow down again.

### Post-deployment boot checks
- **Update reboot passed, 2026-10-17 at 11:44 EDT**: `ssh gimli sudo -n systemctl reboot`; new boot ID `028fb879…`, Linux 6.18.56, booted `3wirlf8…`, `running`, zero failed system and user units. The tmux server came up as 3.7b. All six sessions were restored with an unchanged layout, and `restore-terminals` attached its three windows on attempt 1. Re-sourcing the config and `save-tmux` both succeeded.
- **Passed for storage/system services, 2026-09-21 at 16:59 EDT**: `ssh torag sudo -n systemctl reboot`; expected active/default `fdka1cn…`, new boot ID, Linux 6.18.52, zero failed system units, persisted SMART state, unchanged scrub-result hash/timer timestamp, and active monitoring verified. The user terminal-restoration failure below remains.

### Desktop runtime
Hyprlock restart/activation survival, idle locking, password unlock, suspend/resume, and fresh login verified 2026-09-21–22 on `4xbk1mj…`. am live verification deferred by Brian; task 35 accepted on Torag evidence.

- **Logout crashes, newly recorded 2026-09-22**: the approved locked-session `hyprctl -i 0 dispatch exit` test at 22:28 EDT September 21 produced a Hyprland 0.55.4 SIGSEGV and Hyprlock 0.9.5 / Hyprpaper SIGABRTs. Hyprlock reported `ASSERTION FAILED! [core] Disconnected from pollfd id 0`. DrKonqi's coredump launcher then repeatedly aborted. Logout reached the greeter, graphical targets eventually stopped, and the next login worked with no orphan locker. Inspect compositor teardown and the crash-launcher cascade; a clean locked logout remains unverified.
- **Terminal restore timeout, newly recorded 2026-09-21**: `restore-terminals.service` failed at 16:44:59 EDT during Home Manager activation and again at 17:00:05 after reboot with `Timed out waiting for tmux-resurrect to restore terminal sessions`. Inspect its saved-session/readiness checks; this is a user-service failure even when the system-level `systemctl --failed` is clean.

### `health`
Checked 2026-10-17 at 11:30 EDT with `nix develop W -c health gimli`, system `3wirlf8…` (nixpkgs 26f4107, before reboot): **exit 1** for the Dependabot unit below; no failed system units, root 39% used / 581 GiB available, `/boot` 45% / 279 MiB free, two Syncthing peers. Wi-Fi on 5220 MHz with wpa_supplicant 2.12. Earlier intermittent conditions remain unverified.

- **Dependabot check, bad GitHub token, newly recorded 2026-10-17**: user unit `check-dependabot-alerts.service` (added in `2ff0d69`) fails with `gh: Bad credentials (HTTP 401)`; `gh auth status` reports the token in `~/.config/gh/hosts.yml` is invalid. durin's instance succeeds. Brian needs to run `gh auth refresh -h github.com` on gimli.

- **Crash processors failed, newly recorded 2026-09-22**: four `drkonqi-coredump-processor@*.service` units remained failed after the logout crash cascade above. Their failed states were gone by 2026-10-03 after Torag's reboots; the triggering logout crash was not re-exercised. Inspect the processing/launcher errors if they recur; `just health` exits zero despite reporting these failures.
- **Startup failure notification unavailable, newly recorded 2026-09-22**: at 09:51 EDT, `check-failed-services.service` exited 1 with `Failed to show notification: …NoReply: Remote peer disconnected`, alongside failed D-Bus notification-service activations. The later user failed-unit list is empty. Check notification-daemon readiness and the checker's startup ordering; initial failure alerts can be missed.
- **ucsi_acpi**: `PPM init failed` — USB Type-C firmware issue, hardware
- **spd5118**: `Failed to write` / `failed to resume async: error -6` — RAM SPD sensor resume error after sleep, hardware
- **D-Bus/menu activation noise, newly recorded on torag**: duplicate accessibility, Blueman, dconf, and portal service names, plus `plasma-apply-lookandfeel` reporting `"applications.menu" not found`. These match am's existing findings; activation succeeds with zero failed units. Review duplicate service exports and the one-shot menu lookup if eliminating the noise.

### `vim-health`
Rechecked 2026-10-17 with `nix develop W -c health gimli`, system `3wirlf8…` (nixpkgs 26f4107). The existing warnings remain.

- **WARNING**: render-markdown LaTeX helpers `utftex` and `latex2text` are absent
- **WARNING**: Neovim 0.12.6 is available while the configured nixpkgs package is 0.12.4
- **WARNING**: `yaml.docker-compose`, `yaml.gitlab`, and `yaml.helm-values` unknown filetypes — upstream LSP config advertises filetypes not known to this Neovim runtime
- **WARNING**: `No clipboard tool found` — observed in the SSH-launched headless check; GUI-session clipboard behavior was not exercised
- **WARNING**: `biber is not executable!` — same as am

### `gnome-health`
- Clean on 2026-10-17: `nix develop W -c health gimli`, system `3wirlf8…` (nixpkgs 26f4107).

## Remote builds (`remote-builds-health`)
- Passed 2026-10-17 at 11:33 EDT from durin (`nix develop W -c remote-builds-health`), with durin `d7hnfawm…`, narvi `6aadmsm…` and gimli `3wirlf8…`: all 16 SSH, fresh remote-build, HTTP-cache and signature-verified transfer assertions, with no warnings.

## Update tooling

Newly recorded 2026-09-12 during the update; recovered coverage and raw evidence are documented in `update-reports/2026-09-12.md`.

- **Prebuilt-system rebuild invocation, newly recorded 2026-10-09**: `nixos-rebuild test --sudo --store-path <system>` failed before activation with `file 'nixos-config' was not found in the Nix search path`, while evaluating `config.system.build.nixos-rebuild` from `<nixpkgs/nixos>`. The normal `--flake .#am` invocation passed. Inspect the CLI's re-exec handling for `--store-path`; this failure did not change the active system.
- **Suppressed package-extraction errors**: `nixpkgs-changelog` silently continued after the Linearis version assertion prevented Home Manager evaluation (231 rather than 408 package names). Fix individual evaluation error reporting and inventory coverage; the current extractor omits some profiles and option-injected dependencies. The update repaired the pin and reviewed the complete commit range independently.
- **Regex package false positives**: `[26.05]` was passed unescaped to `grep`, producing an unrelated `jwx` match. Use literal package matching; this false positive was rejected by configuration/source review.
- **Missing non-Git inputs**: `flake-changelog` compares only `.rev`, omitting changed `linearis-npm` registry metadata; recurred 2026-10-03 and 2026-10-17 for `opencode2-npm` (2.0.12 → 2.0.22 → 2.0.32), each time resolved manually. Compare locked content for file inputs and report their non-Git identity.
- **Activation killed with its calling session, newly recorded 2026-10-03**: `nh` runs `switch-to-configuration` as a direct child (locally via `sudo`, remotely inside the SSH session) instead of in a transient unit. On am, Home Manager activation restarted the OpenCode server that owned the shell, killing the switch after its stop phase. PostgreSQL, systemd-oomd, Docker and accounts-daemon stayed stopped until `nh os test` was rerun. On Balrog, the switch restarted `tailscaled` (new tailscale build), which terminated the Tailscale SSH session and the switch with it. `nixos-rebuild switch --target-host … --sudo` (used for Torag) wraps the switch in `systemd-run --pipe`, which is **not sufficient**: the unit survived the SSH drop but exited 101 mid-switch, likely on its broken output pipe. Only a detached `systemd-run` without `--pipe` completed reliably. `deploy` now accepts `boot` (completed task "Revise flake-update workflow and justfile deploy"), but `deploy switch`, the default and the flake-update skill's step, still runs the switch under the caller. On 2026-10-17 `tailscaled` restarted on durin even though tailscale itself did not change (dependency changes), and OpenCode 2.0.32 restarted `opencode-serve`. The update stayed safe by using a detached `test` on durin, `deploy boot` for all hosts, a reboot for narvi, and a detached `switch` on gimli. Make `deploy switch` and the skill use a detached, unpiped switch.
- **Update artifacts lost on reboot, newly recorded 2026-10-03**: the flake-update skill writes evidence to `/tmp/flake-update/…`, which the ephemeral root wipes at reboot; the 2026-10-03 report's artifact paths no longer exist. Write artifacts somewhere persisted (or into the update worktree, uncommitted) before any reboot step. Still open on 2026-10-17: the skill still writes to `/tmp`. That update's artifacts were copied by hand to the persisted `/home/bbrian/Code/flake-update-artifacts/update-10-17-26`.
- **keep-awake over SSH, newly recorded 2026-10-03**: `ssh torag keep-awake toggle` fails with `XDG_RUNTIME_DIR: parameter null or not set` (line 131); it works after exporting `XDG_RUNTIME_DIR=/run/user/$(id -u)`. The earlier `keep-awake 24h` form used by update workflows no longer exists (`toggle | status | matches`). Default `XDG_RUNTIME_DIR` in the script and update the update workflow's keep-awake commands.

## OpenCode runtime

Newly recorded while verifying notifications on am, 2026-09-13, using
OpenCode `0.0.0-beta-19271`. These are runtime/CLI observations, separate from the
passing notification tests and Nix activation above.

- **Truncated large API output**: `opencode2 api get '/api/session?limit=500' | jq ...` failed with `Unfinished string at EOF` around byte 159744. The native client returned valid complete pages (517 sessions across two pages). Investigate the CLI's stdout/output handling; the notification plugin uses the native client.
- **Directory watcher unavailable**: the server logs `watcher backend not supported`, `platform=linux`, for the OpenCode configuration and skill directories; individual file watchers report `backend=node`. Existing locations retained old plugin registrations after activation while newly loaded locations saw the new configuration. Investigate directory watching and hot-discovery in the packaged runtime.
- **OpenAI override normalization**: loading a location logs `configuration normalization diagnostic`, `path=$.provider.openai`, `kind=invalid`, `skipped malformed recognized value`. The exact rejected field is not identified by this warning. Inspect normalization/resolved provider configuration before relying on these custom overrides.
- **Slack resource-template discovery**: location activation logs `failed to list MCP resource templates`, `MCP error -32601: Method not found: resources/templates/list`. Template discovery is unavailable on that integration; investigate capability-aware probing upstream.
- **Auto-tabs passed, 2026-09-21, OpenCode 2.0.12**: a disposable live TUI retained its selected tab and opened an API-created same-directory session in the background; other-directory sessions were excluded. Plugin type checks, all 45 tests, and packaged load/reload checks passed. Existing beta clients need restarting to use the corrected tab API.
- **Restart cancellation status, newly recorded 2026-09-20**: after a server restart, three background shell tools reported cancellation while their underlying commands continued and later wrote exit records. The original shell-output path also disappeared. On 2026-10-03, a foreground `nh os test` reported `Command cancelled` when its own activation restarted the server, and this time the command really was killed: there was no exit record and no `finished switching`. Inspect durable command logs/exit records before retrying; investigate the harness's subprocess lifecycle and cancellation reporting.
- **YAML language server unavailable, newly recorded 2026-09-20**: automatic diagnostics for an upstream Brave YAML rewrite reported `Executable not found in $PATH: "yaml-language-server"`. Plain source inspection succeeded; YAML LSP validation was unavailable. Check the configured server command and its executable environment before relying on these diagnostics.
