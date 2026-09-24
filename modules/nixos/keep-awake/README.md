# Keep awake

`workload-inhibit.service` (on by default for GUI machines) runs
`keep-awake monitor`, which scans `/proc` every two seconds for important work,
regardless of launcher, shell, user, or session. The recognized commands are the
`case` in `workload` in `keep-awake.sh`: NixOS rebuilds/activation, `nh os`,
`local-deploy`, `just deploy[-devshell]`, Nix builds/checks/copies, remote Nix
serving, and anything run by a Nix build user. Matching is deliberately loose, so
a false positive only delays sleep. Code passed to `sh -c` and similar is ignored.

While anything matches, the monitor holds one logind sleep inhibitor. Its reason
lists what matched. The hold is released five seconds after the last match
disappears, which bridges gaps between build phases. Detection is sampled, so
work that starts right before a suspend can be missed. Nothing is persisted: if
the monitor dies, systemd kills its inhibitor and restarts the monitor.

## Controls and inspection

- `keep-awake toggle`: toggle the manual hold, also available through Waybar
  click or **Alt+Shift+A**. The user service holding it stops at logout.
- `keep-awake` / `keep-awake status`: current sleep blockers and monitor health.
- `keep-awake matches`: what the monitor currently recognizes.
- `systemd-inhibit --list`: logind's view, including unrelated inhibitors.
- `journalctl -u workload-inhibit`: holds taken and released.

Waybar distinguishes automatic, manual, combined, and other application holds.

Only sleep is inhibited; automatic locking stays enabled. If a hold blocks
Hypridle's suspend, sleep waits for the next idle cycle. Explicit suspend also
respects the hold. Each machine only watches its own processes, so protecting a
remote deploy requires this module on the target.
