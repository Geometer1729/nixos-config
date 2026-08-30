# Remote NixOS installer

This generic x86_64 installer ISO uses DHCP, enables key-only root SSH with the
keys from `ssh-authorized-keys.nix`, and includes `disk-report` for safely
identifying installation targets.

Build it with:

```sh
nix build -o result-installer path:.#nixosConfigurations.installer.config.system.build.isoImage
```

After booting it, find `nixos-installer` in the router's DHCP leases and connect
with `ssh root@<installer-ip>`. Run `disk-report /dev/sdX` before configuring a
Disko target. The ISO itself never partitions or installs anything.
