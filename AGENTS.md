# Agents.md

This repository is a NixOS configuration repo built with flakes, `nixos-unified`, NixOS modules, and home-manager modules.

The north star of everything here is declaritive configuration.
Nearly all configuration of this machine should come from this repo.

## Placement Rules

- Keep shared logic in `modules/`.
- Keep machine-specific logic in `configurations/`.
- Avoid hostname conditionals in shared modules.
- Put application-specific behavior in the relevant application module.
- Put general scripts in `modules/home/scripts/`.

## Testing

- If you create a new file that must be visible to flakes, `git add` it before any build.
- Verify meaningful config changes before calling the work done.
- Default verification for NixOS changes is `nixos-rebuild test`.

## Impermanence

A big part of keeping this machine declaritive is impermanence.
State is only allowed via a narrow whitelist to minimize the risk of
persistent configuration not controled by this config.

- Root is ephemeral.
- Only explicitly persisted paths survive reboot.
- New persistence mounts can hide old data rather than deleting it.
- If persisted data seems missing after activation, check whether it is hidden behind the mount.
- Changes that seem fine immediately after activation can still fail after the next boot if persistence is wrong.

## Useful Repo Facts

- `just` contains common project commands.
- `nix develop` enters the development shell.
- `am` is the primary desktop.
- `torag` is the secondary machine.

## Update Reports

Especially if I mention something used to work there's a good chance it was broken by a recent update. The ./update-reports directory may already contain helpful info.

