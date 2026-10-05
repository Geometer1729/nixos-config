# Known Warnings And Check Failures

Verification is scoped to each section; a partial refresh does not update the
baseline for unchecked hosts or commands.

## Evaluation warnings

This section is only for evaluation warnings in `nix flake check` or `nix build *` for this repo.

Verified 2026-10-03 with full `nix flake check -L` (update worktree,
nixpkgs 774debe). Evaluation and check builds passed on x86_64-linux; the following findings remain:

- **Custom flake output**: `unknown flake output 'nixos-unified'` — an intentional framework output whose schema Nix's checker does not recognize. No configuration change is needed.
- **Omitted systems**: `The check omitted these incompatible systems: aarch64-darwin, aarch64-linux, x86_64-darwin` — the framework advertises four platforms by default. Decide whether to narrow the supported systems to x86_64-linux or validate the other platforms with `--all-systems`.

- **Nix database contention during concurrent evaluations**: the 2026-09-20 flake check warned `SQLite database '/nix/var/nix/db/db.sqlite' is busy`; the September 14 plugin checks reported the analogous warning for `…/.cache/nix/eval-cache-v6/….sqlite`. Both runs ultimately passed; the final update checks emitted only the two warnings above. Recheck if contention recurs without concurrent evaluations; no database repair or deletion was needed.

- **Cold eval-only source-store failure, newly recorded 2026-09-23**: Nix 2.35.2 `nix flake check --no-build` failed before output evaluation with `path '/nix/store/<hash>-<hash>-source' is not valid`; `--refresh` also failed. Direct builds and flake metadata passed. Full `nix flake check -L` materialized the missing path, after which eval-only checking passed too. Investigate read-only flake source materialization; no Nix fix was applied. Evidence: `/tmp/opencode/waybar-modes-eval{,-final,-after-full-check}.log` and `waybar-modes-checks.log`.

## Flake checks

- **Passed, 2026-10-03**: full `nix flake check -L` (nixpkgs 774debe), including all three host builds and the OpenCode plugin load/reload check. ISO build/boot and other advertised platforms remain unverified.
- **Plugin-check npm warnings, newly recorded 2026-09-21**: `opencode-plugins-check` reports unknown environment config `nodedir` and deprecated transitive `node-domexception@1.0.0`, `glob@9.3.5`, and `glob@10.5.0`. Since 2026-10-03 (plugins on `@opencode/plugin` 2.0.22) it also reports `EBADENGINE`: `@opentui/core@0.5.14` requires `node >=26.4.0` / `bun >=1.3.0`, but the check runs Node 24.21.0. Typecheck and all 46 tests pass; OpenCode loads plugins under its bundled Bun at runtime. Move the check to a satisfying runtime if Node-specific failures appear; otherwise follow the npm hook and dependency updates rather than suppressing the warnings.

## installer

### Build and activation
- **ISO build passed, 2026-09-12 (nixpkgs 6713828)**; never boot-tested. On 2026-09-20, updated nixpkgs cf9d2fb passed configuration evaluation only; the updated ISO build/boot remains unverified.

## am (primary desktop)

### Build and activation
- **Passed, 2026-10-03**: update worktree `nh os build` and `nh os test` (`g344m3k…`; the first `nh os test` was interrupted, see "Activation killed with its calling session" under Update tooling). Then, after merging master's substituter fix (`f7909df`), `nh os switch W -H am --target-host bbrian@am` at 22:51 EDT: active/default `p13nsrb…` (nixpkgs 774debe), no failed system or user units.
- **PrismLauncher build warnings**: Java source/target 7 and Applet APIs are obsolete, and CMake reports unused `CMAKE_EXPORT_NO_PACKAGE_REGISTRY`; both remain in the 2026-10-03 12.0-develop build. The Qt AutoUic duplicate-`verticalLayout` warning is resolved upstream (`c2ef89ec`) and absent from that build. Build/tests pass; track upstream compiler packaging rather than removing legacy support.
- **PrismLauncher intermittent check timeout, newly recorded 2026-09-20**: `ResourceFolderModelTest::test_removeResource()` line 161 expires its 10-second timer during the initial fixture installation, causing checkPhase exit 8. The test and affected path are unchanged; upstream PR #5912 documents prior timing failures. The same derivation passed all 22 tests on retry, and the 2026-10-03 build passed 23/23 on its first attempt; the intermittent condition was not re-exercised. Exact delay cause is unknown; retain a disposable build tree for isolated/full-class reproduction before proposing a fix. No tests were disabled.
- **Initrd alternate-library warnings, newly recorded 2026-09-20**: `Couldn't satisfy dependency libcrypt.so.1` / `.so.1.1`, unchanged with systemd 260.4 (2026-10-03). The initrd builder checks each dlopen SONAME alternative separately. The actual old am and all three new host initrds contain byte-identical `libcrypt.so.2`; no missing password-hashing implementation was found. No workaround needed; follow upstream warning handling. Balrog's 6.18.54 initrd also passed its 2026-10-03 reboot check below.
- **System-path collisions, newly recorded**: `pkgs.buildEnv` ignores duplicate PostgreSQL 18.6 `bin/postgres` and Xwayland/Xorg `protocol.txt` / `Xserver.1.gz`. The PostgreSQL service explicitly uses `postgresql-and-plugins` and is active; the global CLI selects the base package. X-server collisions concern documentation. Review duplicate package exposure if these warnings are to be eliminated.
- **Info-index warning, newly recorded**: `install-info` reports no directory entry in `gawknotes.info`. Build succeeds; the supplemental document lacks index metadata. Follow upstream packaging if an index entry is needed.
- **Upstream derivation build-log noise, newly recorded 2026-10-03**: derivations built locally rather than substituted print their own deprecation warnings. Examples: setuptools license-classifier/`setup.py install` deprecations (vit, tasklib, ranger, nixos-render-docs); ImageMagick 7 `convert` deprecation (nixos-icons, stylix-grub); `Fontconfig error: No writable cache directories` (nerd-fonts); GSettings `/system/` schema-path deprecations (steam FHS rootfs); Discord's declared `autoPatchelfIgnoreMissingDeps` for `libcrypto.so.1.1`; and C++/libxml2 deprecations in Inkscape/gtksourceview during flake check. All builds succeed. These come from upstream package builds, not from this configuration; no action unless one becomes an error.

### Desktop runtime
- **KDE portal host-registration warning, newly recorded 2026-09-29**: after restoring discovery of the KDE backend, its startup reports `Failed to register with host portal` / `Connection already associated with an application ID`. The portal starts, `OpenDirectory` accepts the previously failing request, and Brian confirmed Brave's folder button works. The duplicate association's cause is unverified; inspect the KDE/host-portal registration sequence before changing registration behavior.
- **fwupd refresh resume race, newly recorded 2026-09-27**: on September 26 at 21:44:50 EDT, `fwupd-refresh.service` exited 1 with `Could not resolve host: cdn.fwupd.org` after its timer fired on resume; DHCP restored IPv4 at 21:44:54. A 30-second failure retry with five starts per ten minutes is active on am; loaded settings and a real metadata download passed September 27 at 08:37:56 EDT. Recovery through a retry after suspend remains unverified; check the next affected resume. Upstream success statuses `2 101` remain exempt from retries. Torag's shared policy was evaluated only.
- **Terminal snapshot loss on shutdown, patched 2026-09-20**: tmux pane scopes stopped during the logout save (`no server running`); tmux-resurrect promoted an incomplete snapshot, causing the next boot's terminal-restore timeout. Scope ordering now holds panes and Ghostty-hosted servers until saving finishes. `just test-tmux-shutdown` reproduced early teardown before the fix and passed afterward on am. End-to-end reboots on am (2026-10-03 23:05 and 2026-10-04 10:36) restored complete snapshots; Torag's end-to-end reboot remains unverified. Snapshot publication still lacks validation for other save failures.
- **Terminal window not reopened at boot, newly recorded 2026-10-03**: at the 23:06 boot, `restore-terminals` finished successfully but no Ghostty window appeared for the manifest's only session; the same `hyprctl dispatch exec` worked when re-run later. The cause is unknown. Since 2026-10-04 the script logs each dispatch, confirms that a client attached, retries up to three times, and fails the unit if none attaches. The 2026-10-04 10:36 boot attached on attempt 1. Check the `restore-terminals` journal if a window is missing again.
- **Waybar aborts when PipeWire restarts, newly recorded 2026-10-03**: whenever activation stops or restarts PipeWire, waybar's PulseAudio module throws `pa_context_connect() failed: OK` (`std::runtime_error`, SIGABRT, core dumped). On am this happened at 13:23, 22:14 and 22:47 EDT; on Torag at 22:57. The service restarts and is active within seconds; no failed units remain. Make the PulseAudio module survive a server restart (upstream waybar reconnect handling), or order/restart waybar after PipeWire on activation.
- **Waybar minimum height, newly recorded 2026-09-14**: restarting `waybar.service` reports `Requested height: 24 is less than the minimum height: 34 required by the modules` on both monitors; both bars run at 34 px. The same warning appears in September 11–12 logs before the AI usage module. Align the requested height with the existing font/padding, or revisit sizing if a 24 px bar is desired.
- **Hypridle ScreenSaver cookie accounting, newly recorded 2026-09-23**: `No cookie in uninhibit` / `BUG THIS: inhibit locks < 0: -1` appeared after the idle-daemon restart. The same warnings occur on September 20 and 22, before the workload observer. Subsequent Brave Video Wake Lock acquire/release messages return the count to 1/0. Inspect Hypridle's cookie handling across client/daemon restarts; locking behavior during an unmatched release remains unverified.

### `health`
Checked 2026-10-03 at 23:19 EDT after reboot (Linux 6.18.54, `p13nsrb…`): no failed system or user units, root 81% used / 172 GiB available, two Syncthing peers, existing duplicate D-Bus/menu journal warnings, and the Bluetooth signature below. Earlier intermittent boot/hardware conditions were not re-exercised.

- **obexd**: `stat(/home/bbrian/phonebook/): No such file or directory` — bluetooth phonebook directory doesn't exist, cosmetic
- **kvm_amd**: `SVM not supported by CPU <n>` — hardware doesn't support nested virtualization. When activation restarts `systemd-modules-load`, the same cause also logs `Failed to insert module 'kvm_amd': Operation not supported` (2026-10-03).
- **Keep-awake helper restart, newly recorded 2026-10-03**: `systemd-inhibit[…]: 'sleep' terminated by signal TERM` when activation restarts `workload-inhibit.service`. The service came back active; this is the expected stop of its placeholder inhibitor process.
- **Bluetooth RTL**: `hci1: RTL: RTL: Read reg16 failed (-110)` — hardware/firmware issue, harmless. On 2026-10-03 at 23:19 the same adapters also logged `hci1: command 0x0401 tx timeout` / `Resetting usb device` and `hci2: RTL: Failed to generate devcoredump`, about 12 minutes after boot. Bluetooth recovered without failed units; recheck if devices drop.
- **ACPI USB _PLD**: `AE_AML_UNINITIALIZED_ELEMENT` for `PTXH.RHUB.POT7._PLD` — firmware ACPI table issue surfaced in the boot journal
- **dbus-broker duplicate service names**: duplicate names for Blueman, dconf, accessibility, and xdg-desktop-portal service files after boot/activation — noisy but services are still running
- **plasma-apply-lookandfeel**: `"applications.menu" not found` during Home Manager activation — one-shot menu lookup noise; activation still succeeds
- **Bluetooth HFP SDP**: `Unable to get Hands-Free Voice gateway SDP record: Host is down` — Bluetooth device/service availability noise

### `vim-health`
Rechecked 2026-10-03 on system `g344m3k…` (nixpkgs 774debe); the following existing warnings remain.

- **WARNING**: render-markdown LaTeX helpers `utftex` and `latex2text` are absent
- **WARNING**: Neovim 0.12.5 is available while the configured nixpkgs package is 0.12.4
- **WARNING**: `yaml.docker-compose`, `yaml.gitlab`, and `yaml.helm-values` unknown filetypes — upstream LSP config advertises filetypes not known to this Neovim runtime
- **WARNING**: `biber is not executable!` — LaTeX bibliography tool, not installed globally (vimtex plugin check)

### `gnome-health`
- Clean on 2026-10-03: `just gnome-check`, system `g344m3k…` (nixpkgs 774debe).

## balrog

### Build and activation
- **Deployed with manual completion, 2026-10-03 (twice)**: both `nh os switch … --target-host bbrian@balrog` runs (13:53 from `just deploy`, and 22:51 after a cf9d2fb master deploy had downgraded tailscale again) lost their session when the switch restarted `tailscaled`. See "Activation killed with its calling session" under Update tooling. Podman/Foundry, nix-serve, smartd, taskchampion-sync-server, systemd-oomd and nscd were left stopped, and the profile still pointed at the old system. Each was completed with `sudo systemd-run --collect <system>/bin/switch-to-configuration switch` (the Foundry race below can make it exit 4), then `nix-env -p /nix/var/nix/profiles/system --set` and a detached `switch-to-configuration boot`. Final active/default system `sjk916z…` (nixpkgs 774debe plus the substituter fix).
- **Foundry startup-health race, moved from am**: Podman's transient `<container-id>-<suffix>.service` runs `healthcheck run` immediately after starting Foundry, returns 1 while health is `starting`, and can make NixOS activation exit 4. Reproduced during Balrog's September 26 activation and reboot and the 2026-10-03 completion switch. Later timer probes cleared the failed state without a reset. Upstream tracks the same failure for all transient units as [nixpkgs #558533](https://github.com/NixOS/nixpkgs/issues/558533). Follow up on startup/readiness handling, or on that fix, rather than disabling the health check.

### FoundryVTT runtime
- **Auth DNS, moved from am**: `getaddrinfo EAI_AGAIN foundryvtt.com` recurred during Balrog's September 26 boot/authentication, and again at the 2026-10-03 23:04 boot (`Unable to authenticate: request to https://foundryvtt.com/ failed`). Later container DNS lookup passed and Foundry was healthy; investigate startup network readiness if this continues.
- **License-verification startup message, newly recorded 2026-09-26**: `Software license verification failed` appeared on am before migration and Balrog after reboot. The browser initially reached `/license`, then reached `/auth`; the container is healthy. The message's cause is unverified; check licensing if it recurs or blocks world access. This predates the migration.

### `health`
Checked 2026-09-21 on `r7v1p7f…` by running the recipe's component commands over SSH (Balrog has no `/home/bbrian/conf/justfile`): no failed system units, root 26% used / 168 GiB available, and two Syncthing peers.

- **D-Bus duplicate service names, newly recorded on Balrog**: boot journal reports duplicate dconf and systemd service names, matching the desktop hosts' existing warning class. Review duplicate service exports if eliminating the noise.

### Post-deployment boot checks
- **Update reboot passed, 2026-10-03 at 22:53:34 EDT**: `ssh balrog sudo -n systemctl reboot`; new boot ID, Linux 6.18.54, booted/active/default `sjk916z…`, zero failed system and user units; Foundry, nginx, nix-serve, smartd and taskchampion-sync-server active. Briefly `degraded` at boot from the Foundry healthcheck transient, then `running`. Rebooted again at 23:04 with the same result (Foundry HTTP 200, 29% root used, two Syncthing peers). An earlier 13:55 reboot into `fjr0asf…` also passed.
- **Foundry checks passed, 2026-09-26**: rebooted into expected active/booted/default `c42xf9x…`; original image/version 13.351.0, persistent data/image mounts, data-content checksum comparison, LAN HTTP, and no failed system or user units verified after the startup-health transient cleared.
- **Storage checks passed, 2026-09-21 at 16:59 EDT**: `ssh balrog sudo -n systemctl reboot`; new boot ID, expected active/default `r7v1p7f…`, Linux 6.18.52, zero failed system units, persisted SMART state, unchanged scrub-result hash/timer timestamp, and active monitoring verified. Alert delivery to am also passed after reboot.
- **Secrets/sync boot checks passed, 2026-09-21 at 20:52 EDT**: rebooted into expected active/booted/default `xhsxkk6…`, Linux 6.18.52. Both SOPS steps imported only the persisted user SSH key, expected secrets were readable, automatic Taskwarrior sync succeeded at 20:48 EDT without corrective activation, and system/user failed-unit lists were empty.

### Storage health
- **Unsupported SMART attributes, 2026-09-21**: smartd reports no attributes 197 (`Current_Pending_Sector`) or 198 (`Offline_Uncorrectable`) on the Samsung 860 EVO. `smartctl -a` confirms these are absent from the device's attribute table; supported attributes and overall health are monitored. No suppression or configuration change is needed.

## torag (secondary machine)

### Build and activation
- **Passed, 2026-09-21**: Hyprlock fix, `nixos-rebuild test --flake .#torag --target-host bbrian@torag --sudo --use-substitutes`, active system `4xbk1mj…`. Boot default remains `fdka1cn…`.
- **Deployed with manual completion, 2026-10-03 at 22:54–22:58 EDT**: `nixos-rebuild switch --flake W#torag --target-host bbrian@torag --sudo --use-substitutes`. The copy took about 1.5 min (198 paths: 114 from `http://am:5000`, 84 from cache.nixos.org). The switch restarted `tailscaled`, and SSH dropped (exit 255). The detached `nixos-rebuild-switch-to-configuration.service` (`systemd-run --pipe`) then exited **101**, likely panicking on the broken output pipe, without `finished switching`; nscd and systemd-oomd were left stopped. It was completed with `sudo systemd-run --collect --wait <system>/bin/switch-to-configuration switch` (no pipe), which finished successfully. Active/default `zhhf445…` (nixpkgs 774debe). Not rebooted: still running Linux 6.18.52. Two earlier attempts (19:49 and 21:18) were killed during copy over 2.4 GHz Wi-Fi.

### Network
- **Wi-Fi throughput on 2.4 GHz, newly recorded 2026-10-03**: Torag joins `moria` on 2412 MHz / 20 MHz when the router doesn't offer 5 GHz under that SSID. In that state, LAN RTT is 13–510 ms (0.5–1.6 s under load) and SSH throughput ~2 MiB/s. On 5 GHz / 80 MHz it gets ~50 MiB/s. The 5 GHz BSS came and went during the evening; at 22:42 Torag was on 5220 MHz (816 Mbit/s PHY rate) and the deploy copy was fast. The `ssh-ng` substituter that made slow links unbearable was replaced by `http://am:5000?priority=50` (`7bbd75f`). Recheck the band if deploys slow down again.

### Post-deployment boot checks
- **Update reboot passed, 2026-10-03 at 23:04 EDT**: `ssh torag sudo -n systemctl reboot`; new boot ID, Linux 6.18.54, booted/active `zhhf445…`, `running`, zero failed system and user units, still on 5 GHz.
- **Passed for storage/system services, 2026-09-21 at 16:59 EDT**: `ssh torag sudo -n systemctl reboot`; expected active/default `fdka1cn…`, new boot ID, Linux 6.18.52, zero failed system units, persisted SMART state, unchanged scrub-result hash/timer timestamp, and active monitoring verified. The user terminal-restoration failure below remains.

### Desktop runtime
Hyprlock restart/activation survival, idle locking, password unlock, suspend/resume, and fresh login verified 2026-09-21–22 on `4xbk1mj…`. am live verification deferred by Brian; task 35 accepted on Torag evidence.

- **Logout crashes, newly recorded 2026-09-22**: the approved locked-session `hyprctl -i 0 dispatch exit` test at 22:28 EDT September 21 produced a Hyprland 0.55.4 SIGSEGV and Hyprlock 0.9.5 / Hyprpaper SIGABRTs. Hyprlock reported `ASSERTION FAILED! [core] Disconnected from pollfd id 0`. DrKonqi's coredump launcher then repeatedly aborted. Logout reached the greeter, graphical targets eventually stopped, and the next login worked with no orphan locker. Inspect compositor teardown and the crash-launcher cascade; a clean locked logout remains unverified.
- **Terminal restore timeout, newly recorded 2026-09-21**: `restore-terminals.service` failed at 16:44:59 EDT during Home Manager activation and again at 17:00:05 after reboot with `Timed out waiting for tmux-resurrect to restore terminal sessions`. Inspect its saved-session/readiness checks; this is a user-service failure even when the system-level `systemctl --failed` is clean.

### `health`
Checked 2026-10-03 at 22:59 EDT and again after the 23:04 reboot with `ssh torag just --justfile /home/bbrian/conf/justfile health`, system `zhhf445…` (nixpkgs 774debe): zero failed system/user units, root 37% used / 598 GiB available, `/boot` 45% / 280 MiB free, two Syncthing peers, existing D-Bus duplicate-name warnings, and (before the reboot) the waybar abort recorded under am's Desktop runtime. vim-health, gnome-check and `test-remote-builds` (16/16) also passed after the reboot. Earlier intermittent conditions remain unverified.

- **Crash processors failed, newly recorded 2026-09-22**: four `drkonqi-coredump-processor@*.service` units remained failed after the logout crash cascade above. Their failed states were gone by 2026-10-03 after Torag's reboots; the triggering logout crash was not re-exercised. Inspect the processing/launcher errors if they recur; `just health` exits zero despite reporting these failures.
- **Startup failure notification unavailable, newly recorded 2026-09-22**: at 09:51 EDT, `check-failed-services.service` exited 1 with `Failed to show notification: …NoReply: Remote peer disconnected`, alongside failed D-Bus notification-service activations. The later user failed-unit list is empty. Check notification-daemon readiness and the checker's startup ordering; initial failure alerts can be missed.
- **ucsi_acpi**: `PPM init failed` — USB Type-C firmware issue, hardware
- **spd5118**: `Failed to write` / `failed to resume async: error -6` — RAM SPD sensor resume error after sleep, hardware
- **D-Bus/menu activation noise, newly recorded on torag**: duplicate accessibility, Blueman, dconf, and portal service names, plus `plasma-apply-lookandfeel` reporting `"applications.menu" not found`. These match am's existing findings; activation succeeds with zero failed units. Review duplicate service exports and the one-shot menu lookup if eliminating the noise.

### `vim-health`
Rechecked 2026-10-03 with `ssh torag just --justfile /home/bbrian/conf/justfile vim-health`, system `zhhf445…` (nixpkgs 774debe). The existing warnings remain.

- **WARNING**: render-markdown LaTeX helpers `utftex` and `latex2text` are absent
- **WARNING**: Neovim 0.12.5 is available while the configured nixpkgs package is 0.12.4
- **WARNING**: `yaml.docker-compose`, `yaml.gitlab`, and `yaml.helm-values` unknown filetypes — upstream LSP config advertises filetypes not known to this Neovim runtime
- **WARNING**: `No clipboard tool found` — observed in the SSH-launched headless check; GUI-session clipboard behavior was not exercised
- **WARNING**: `biber is not executable!` — same as am

### `gnome-health`
- Clean on 2026-10-03: `ssh torag just --justfile /home/bbrian/conf/justfile gnome-check`, system `zhhf445…` (nixpkgs 774debe).

## Remote builds (`remote-builds-health`)
- Passed 2026-10-03 at 22:59 EDT from am (`just test-remote-builds`, `p13nsrb…`) and Torag (`ssh torag just --justfile /home/bbrian/conf/justfile test-remote-builds`, `zhhf445…`), with Balrog on `sjk916z…`: all 16 SSH, fresh remote-build, HTTP-cache and signature-verified transfer assertions passed on each, including the new `http://am:5000` cache paths to Balrog and Torag.

## Update tooling

Newly recorded 2026-09-12 during the update; recovered coverage and raw evidence are documented in `update-reports/2026-09-12.md`.

- **Suppressed package-extraction errors**: `nixpkgs-changelog` silently continued after the Linearis version assertion prevented Home Manager evaluation (231 rather than 408 package names). Fix individual evaluation error reporting and inventory coverage; the current extractor omits some profiles and option-injected dependencies. The update repaired the pin and reviewed the complete commit range independently.
- **Regex package false positives**: `[26.05]` was passed unescaped to `grep`, producing an unrelated `jwx` match. Use literal package matching; this false positive was rejected by configuration/source review.
- **Missing non-Git inputs**: `flake-changelog` compares only `.rev`, omitting changed `linearis-npm` registry metadata; recurred 2026-10-03 for `opencode2-npm` (2.0.12 → 2.0.22), which was resolved manually. Compare locked content for file inputs and report their non-Git identity.
- **Activation killed with its calling session, newly recorded 2026-10-03**: `nh` runs `switch-to-configuration` as a direct child (locally via `sudo`, remotely inside the SSH session) instead of in a transient unit. On am, Home Manager activation restarted the OpenCode server that owned the shell, killing the switch after its stop phase. PostgreSQL, systemd-oomd, Docker and accounts-daemon stayed stopped until `nh os test` was rerun. On Balrog, the switch restarted `tailscaled` (new tailscale build), which terminated the Tailscale SSH session and the switch with it. `nixos-rebuild switch --target-host … --sudo` (used for Torag) wraps the switch in `systemd-run --pipe`, which is **not sufficient**: the unit survived the SSH drop but exited 101 mid-switch, likely on its broken output pipe. Only a detached `systemd-run` without `--pipe` completed reliably. Make `just deploy` (and agent-run activations) survive session loss, e.g. with a `deploy-boot` path or a detached, unpiped switch; see taskwarrior task 32.
- **Update artifacts lost on reboot, newly recorded 2026-10-03**: the flake-update skill writes evidence to `/tmp/flake-update/…`, which the ephemeral root wipes at reboot; the 2026-10-03 report's artifact paths no longer exist. Write artifacts somewhere persisted (or into the update worktree, uncommitted) before any reboot step; see taskwarrior task 32.
- **keep-awake over SSH, newly recorded 2026-10-03**: `ssh torag keep-awake toggle` fails with `XDG_RUNTIME_DIR: parameter null or not set` (line 131); it works after exporting `XDG_RUNTIME_DIR=/run/user/$(id -u)`. The earlier `keep-awake 24h` form used by update workflows no longer exists (`toggle | status | matches`). Default `XDG_RUNTIME_DIR` in the script and update the update workflow's keep-awake commands.

## KDE Connect runtime

Verified 2026-09-14 with KDE Connect 26.04.3 on am and torag: `nixos-rebuild test`/`switch`, bidirectional notification forwarding, and Slack/Discord exclusions passed. New upstream runtime warnings remain:

- **Notification resync unsupported, both hosts**: `SendNotificationsPlugin received a packet of type "kdeconnect.notification.request" but doesn't implement receivePacket`. The Linux sender cannot replay existing notifications on reconnect; new notifications pass. Follow upstream resync support; this limitation was accepted when choosing KDE Connect.
- **Structured notification hints unsupported, both hosts**: `Unimplemented conversation of type 'r' 114`. The Linux D-Bus listener cannot decode struct-valued hints such as image data. Text forwarding passes; icon fidelity is unverified. Follow upstream hint parsing support.
- **Desktop/discovery logging**: KDE Connect also reports `"applications.menu" not found` on both hosts, extending the existing desktop-menu lookup finding; torag reports `No uuids found` while probing nearby Bluetooth devices. Tailscale pairing and forwarding pass. Investigate upstream menu lookup and Bluetooth discovery if these messages become disruptive.

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
