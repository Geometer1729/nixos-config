# CLAUDE.md

This repository is a NixOS configuration repo built with flakes, `nixos-unified`, NixOS modules, and home-manager modules.

## Working Style

- Prefer broad guidance over detailed policy.
- Keep changes small, direct, and easy to verify.
- Avoid encoding temporary preferences here unless they are meant to last.

## When To Update This File

Update `CLAUDE.md` when you notice something in this file is wrong or about to become wrong.

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

The main goal here is to preserve a few durable truths about the repo, not to accumulate workflow trivia.
