# Known Warnings And Check Failures

Verification is scoped to each section; a partial refresh does not update the
baseline for unchecked hosts or commands.

## Evaluation warnings

This section is only for evaluation warnings in `nix flake check` or `nix build *` for this repo.

Verified 2026-09-21 with full `nix flake check /home/bbrian/conf`
(SOPS user-key simplification, nixpkgs cf9d2fb). Evaluation and check builds passed on x86_64-linux; these two warnings remain:

- **Custom flake output**: `unknown flake output 'nixos-unified'` — an intentional framework output whose schema Nix's checker does not recognize. No configuration change is needed.
- **Omitted systems**: `The check omitted these incompatible systems: aarch64-darwin, aarch64-linux, x86_64-darwin` — the framework advertises four platforms by default. Decide whether to narrow the supported systems to x86_64-linux or validate the other platforms with `--all-systems`.

- **Nix database contention during concurrent evaluations**: the 2026-09-20 flake check warned `SQLite database '/nix/var/nix/db/db.sqlite' is busy`; the September 14 plugin checks reported the analogous warning for `…/.cache/nix/eval-cache-v6/….sqlite`. Both runs ultimately passed; the final update checks emitted only the two warnings above. Recheck if contention recurs without concurrent evaluations; no database repair or deletion was needed.

## Flake checks

- **Passed, 2026-09-21**: full `nix flake check /home/bbrian/conf` after the SOPS user-key simplification, including lint, Neovim, OpenCode plugin type/load checks, and all three host builds. Installer evaluated; ISO build/boot and other advertised platforms remain unverified.
- **Plugin-check npm warnings, newly recorded 2026-09-21**: `opencode-plugins-check` reports unknown environment config `nodedir` and deprecated transitive `node-domexception@1.0.0`, `glob@9.3.5`, and `glob@10.5.0`. Build/tests pass; follow the npm hook and dependency updates rather than suppressing the warnings.

## installer

### Build and activation
- **ISO build passed, 2026-09-12 (nixpkgs 6713828)**; never boot-tested. On 2026-09-20, updated nixpkgs cf9d2fb passed configuration evaluation only; the updated ISO build/boot remains unverified.

## am (primary desktop)

### Build and activation
- **Passed, 2026-09-21**: storage-health `nixos-rebuild test --flake .#am --sudo`, followed by `nixos-rebuild boot --store-path … --sudo --no-reexec`; active/default system `8nd6qlf…` verified. Reboot of this configuration remains unverified.
- **Foundry startup-health race, newly recorded**: Podman's transient `<container-id>-<suffix>.service` runs `healthcheck run` immediately after starting Foundry, returns 1 while health is `starting`, and can make NixOS activation exit 4. Observed on update activations and a concurrent old-input activation. The container becomes healthy and the failed state clears on later probes without intervention; final steady-state activation passed. Follow up on startup/readiness handling rather than disabling the health check.
- **PrismLauncher build warnings**: Java source/target 7 and Applet APIs are obsolete. The September 20 build also reports unused `CMAKE_EXPORT_NO_PACKAGE_REGISTRY` and Qt AutoUic renaming duplicate `verticalLayout` to `verticalLayout1`. Build/tests pass; track upstream compiler/UI packaging rather than removing legacy support.
- **PrismLauncher intermittent check timeout, newly recorded 2026-09-20**: `ResourceFolderModelTest::test_removeResource()` line 161 expires its 10-second timer during the initial fixture installation, causing checkPhase exit 8. The test and affected path are unchanged; upstream PR #5912 documents prior timing failures. The same derivation passed all 22 tests on retry. Exact delay cause is unknown; retain a disposable build tree for isolated/full-class reproduction before proposing a fix. No tests were disabled.
- **Initrd alternate-library warnings, newly recorded 2026-09-20**: `Couldn't satisfy dependency libcrypt.so.1` / `.so.1.1` for systemd 260.2. The initrd builder checks each dlopen SONAME alternative separately. The actual old am and all three new host initrds contain byte-identical `libcrypt.so.2`; no missing password-hashing implementation was found. No workaround needed; follow upstream warning handling. Balrog's updated initrd also passed its reboot check below.
- **System-path collisions, newly recorded**: `pkgs.buildEnv` ignores duplicate PostgreSQL 18.6 `bin/postgres` and Xwayland/Xorg `protocol.txt` / `Xserver.1.gz`. The PostgreSQL service explicitly uses `postgresql-and-plugins` and is active; the global CLI selects the base package. X-server collisions concern documentation. Review duplicate package exposure if these warnings are to be eliminated.
- **Info-index warning, newly recorded**: `install-info` reports no directory entry in `gawknotes.info`. Build succeeds; the supplemental document lacks index metadata. Follow upstream packaging if an index entry is needed.

### Desktop runtime
- **Waybar minimum height, newly recorded 2026-09-14**: restarting `waybar.service` reports `Requested height: 24 is less than the minimum height: 34 required by the modules` on both monitors; both bars run at 34 px. The same warning appears in September 11–12 logs before the AI usage module. Align the requested height with the existing font/padding, or revisit sizing if a 24 px bar is desired.

### `just health`
Checked 2026-09-21 on system `8nd6qlf…`: no failed system units, root 78% used / 192 GiB available, two Syncthing peers, and the existing duplicate D-Bus/menu journal warnings. Earlier intermittent boot/hardware conditions were not re-exercised.

- **obexd**: `stat(/home/bbrian/phonebook/): No such file or directory` — bluetooth phonebook directory doesn't exist, cosmetic
- **kvm_amd**: `SVM not supported by CPU 23` — hardware doesn't support nested virtualization
- **Bluetooth RTL**: `hci1: RTL: RTL: Read reg16 failed (-110)` — hardware/firmware issue, harmless
- **ACPI USB _PLD**: `AE_AML_UNINITIALIZED_ELEMENT` for `PTXH.RHUB.POT7._PLD` — firmware ACPI table issue surfaced in the boot journal
- **dbus-broker duplicate service names**: duplicate names for Blueman, dconf, accessibility, and xdg-desktop-portal service files after boot/activation — noisy but services are still running
- **plasma-apply-lookandfeel**: `"applications.menu" not found` during Home Manager activation — one-shot menu lookup noise; activation still succeeds
- **FoundryVTT auth DNS**: `getaddrinfo EAI_AGAIN foundryvtt.com` during boot/authentication — transient DNS/network timing unless it persists
- **Bluetooth HFP SDP**: `Unable to get Hands-Free Voice gateway SDP record: Host is down` — Bluetooth device/service availability noise

### `just vim-health`
Rechecked 2026-09-20 on system `iqccw0c…` (nixpkgs cf9d2fb); the following existing warnings remain.

- **WARNING**: render-markdown LaTeX helpers `utftex` and `latex2text` are absent
- **WARNING**: Neovim 0.12.5 is available while the configured nixpkgs package is 0.12.4
- **WARNING**: `yaml.docker-compose`, `yaml.gitlab`, and `yaml.helm-values` unknown filetypes — upstream LSP config advertises filetypes not known to this Neovim runtime
- **WARNING**: `biber is not executable!` — LaTeX bibliography tool, not installed globally (vimtex plugin check)

### `just gnome-check`
- Clean on 2026-09-20: `just gnome-check`, system `iqccw0c…` (nixpkgs cf9d2fb).

## balrog

### Build and activation
- **Passed, 2026-09-21**: SOPS user-key simplification, `nixos-rebuild test --flake .#balrog --target-host bbrian@balrog --sudo --use-substitutes` and remote `sudo nixos-rebuild boot --store-path … --no-reexec`; active/default system `xhsxkk6…` verified.

### `just health`
Checked 2026-09-21 on `r7v1p7f…` by running the recipe's component commands over SSH (Balrog has no `/home/bbrian/conf/justfile`): no failed system units, root 26% used / 168 GiB available, and two Syncthing peers.

- **D-Bus duplicate service names, newly recorded on Balrog**: boot journal reports duplicate dconf and systemd service names, matching the desktop hosts' existing warning class. Review duplicate service exports if eliminating the noise.

### Post-deployment boot checks
- **Storage checks passed, 2026-09-21 at 16:59 EDT**: `ssh balrog sudo -n systemctl reboot`; new boot ID, expected active/default `r7v1p7f…`, Linux 6.18.52, zero failed system units, persisted SMART state, unchanged scrub-result hash/timer timestamp, and active monitoring verified. Alert delivery to am also passed after reboot.
- **Secrets/sync boot checks passed, 2026-09-21 at 20:52 EDT**: rebooted into expected active/booted/default `xhsxkk6…`, Linux 6.18.52. Both SOPS steps imported only the persisted user SSH key, expected secrets were readable, automatic Taskwarrior sync succeeded at 20:48 EDT without corrective activation, and system/user failed-unit lists were empty.

### Storage health
- **Unsupported SMART attributes, 2026-09-21**: smartd reports no attributes 197 (`Current_Pending_Sector`) or 198 (`Offline_Uncorrectable`) on the Samsung 860 EVO. `smartctl -a` confirms these are absent from the device's attribute table; supported attributes and overall health are monitored. No suppression or configuration change is needed.

## torag (secondary machine)

### Build and activation
- **Passed, 2026-09-21**: `nixos-rebuild test --flake .#torag --target-host bbrian@torag --sudo --use-substitutes` and remote `sudo nixos-rebuild boot --store-path … --no-reexec`; active/default system `fdka1cn…` verified, with 279 MiB free in `/boot`.

### Post-deployment boot checks
- **Passed for storage/system services, 2026-09-21 at 16:59 EDT**: `ssh torag sudo -n systemctl reboot`; expected active/default `fdka1cn…`, new boot ID, Linux 6.18.52, zero failed system units, persisted SMART state, unchanged scrub-result hash/timer timestamp, and active monitoring verified. The user terminal-restoration failure below remains.

### Desktop runtime
- **Lock screen lost during activation, newly recorded 2026-09-21**: Home Manager restarted `hypridle` at 16:44:35 EDT during `nixos-rebuild test`, after it had launched `hyprlock` at 16:40:17. Hyprland remained locked with no `hyprlock` process and displayed its “Oopsie daisy” recovery screen; there was no new boot or coredump. `hypridle` uses `KillMode=control-group`, strongly implicating termination of its child locker. Recovered by temporarily enabling `misc:allow_session_lock_restore`, launching `hyprlock`, and restoring the option to false. Follow up by giving the locker an independent service lifetime; the underlying configuration is unchanged.
- **Terminal restore timeout, newly recorded 2026-09-21**: `restore-terminals.service` failed at 16:44:59 EDT during Home Manager activation and again at 17:00:05 after reboot with `Timed out waiting for tmux-resurrect to restore terminal sessions`. Inspect its saved-session/readiness checks; this is a user-service failure even when the system-level `systemctl --failed` is clean.

### `just health`
Checked 2026-09-21 with `ssh torag just --justfile /home/bbrian/conf/justfile health`, system `fdka1cn…`: no failed system units, root 37% used / 600 GiB available, two Syncthing peers, the existing D-Bus/menu journal warnings, and the user terminal-restoration failure above. Earlier intermittent hardware conditions were not re-exercised.

- **ucsi_acpi**: `PPM init failed` — USB Type-C firmware issue, hardware
- **spd5118**: `Failed to write` / `failed to resume async: error -6` — RAM SPD sensor resume error after sleep, hardware
- **D-Bus/menu activation noise, newly recorded on torag**: duplicate accessibility, Blueman, dconf, and portal service names, plus `plasma-apply-lookandfeel` reporting `"applications.menu" not found`. These match am's existing findings; activation succeeds with zero failed units. Review duplicate service exports and the one-shot menu lookup if eliminating the noise.

### `just vim-health`
Rechecked 2026-09-20 with `ssh torag just --justfile /home/bbrian/conf/justfile vim-health`, system `w2i1207…` (nixpkgs cf9d2fb). The existing warnings remain.

- **WARNING**: render-markdown LaTeX helpers `utftex` and `latex2text` are absent
- **WARNING**: Neovim 0.12.5 is available while the configured nixpkgs package is 0.12.4
- **WARNING**: `yaml.docker-compose`, `yaml.gitlab`, and `yaml.helm-values` unknown filetypes — upstream LSP config advertises filetypes not known to this Neovim runtime
- **WARNING**: `No clipboard tool found` — observed in the SSH-launched headless check; GUI-session clipboard behavior was not exercised
- **WARNING**: `biber is not executable!` — same as am

### `just gnome-check`
- Clean on 2026-09-20: `ssh torag just --justfile /home/bbrian/conf/justfile gnome-check`, system `w2i1207…` (nixpkgs cf9d2fb).

## Remote builds (`just test-remote-builds`)
- Passed 2026-09-20 from am (`just test-remote-builds`, system `iqccw0c…`) and Torag (`ssh torag just --justfile /home/bbrian/conf/justfile test-remote-builds`, system `w2i1207…`): all 16 SSH, fresh remote-build, HTTP-cache, and signature-verified transfer assertions passed on each invocation.

## Update tooling

Newly recorded 2026-09-12 during the update; recovered coverage and raw evidence are documented in `update-reports/2026-09-12.md`.

- **Suppressed package-extraction errors**: `nixpkgs-changelog` silently continued after the Linearis version assertion prevented Home Manager evaluation (231 rather than 408 package names). Fix individual evaluation error reporting and inventory coverage; the current extractor omits some profiles and option-injected dependencies. The update repaired the pin and reviewed the complete commit range independently.
- **Regex package false positives**: `[26.05]` was passed unescaped to `grep`, producing an unrelated `jwx` match. Use literal package matching; this false positive was rejected by configuration/source review.
- **Missing non-Git inputs**: `flake-changelog` compares only `.rev`, omitting changed `linearis-npm` registry metadata. Compare locked content for file inputs and report their non-Git identity. The final artifact has an explicitly labeled manual entry and complete direct-input accounting.

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
- **TUI tab API verification limitation, 2026-09-14**: in a disposable TUI on `0.0.0-beta-19271`, `context.ui.tabs.open(second)` navigated to the second session and left only that tab in `tabs.list()`. A live two-tab open/close notification test could not establish its intended background-tab fixture; no notification-code failure was demonstrated by that test. This differs from the current V2 CLI plugin guide's background-opening semantics. Single-TUI attachment/detachment and multi-client socket inventories passed as recorded above.
- **Restart cancellation status, newly recorded 2026-09-20**: after a server restart, three background shell tools reported cancellation while their underlying commands continued and later wrote exit records. The original shell-output path also disappeared. Inspect durable command logs/exit records before retrying; investigate the harness's subprocess lifecycle and cancellation reporting. Update evidence was recovered without rerunning the input update.
- **YAML language server unavailable, newly recorded 2026-09-20**: automatic diagnostics for an upstream Brave YAML rewrite reported `Executable not found in $PATH: "yaml-language-server"`. Plain source inspection succeeded; YAML LSP validation was unavailable. Check the configured server command and its executable environment before relying on these diagnostics.
