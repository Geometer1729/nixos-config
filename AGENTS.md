# Agents.md

This repository is a NixOS configuration repo built with flakes, `nixos-unified`, NixOS modules, and home-manager modules.

The north star of everything here is declaritive configuration.
Nearly all configuration of this machine should come from this repo.

## Placement Rules

- Keep shared logic in `modules/`.
- Keep machine-specific logic in `configurations/`.
- Avoid hostname conditionals in shared modules.
- Put application-specific behavior in the relevant application module.
- When an application requires nixos + home-manager put it in nixos with a `home.nix` and `system.nix` similar to brave.
- Use the scripts option to manage any bash scripts.

## Pinning

Nothing may silently go stale: `nix flake update` must either move every external source or fail until someone updates it.

- Prefer a nixpkgs or `nixpkgs-unstable` package over overriding a package's source.
- Pin other downloads as flake inputs (`flake = false` for non-flakes), not `fetchurl`/`fetchzip`/`fetchFromGitHub` with a hardcoded hash.
- Track a branch or a `latest` URL, not a fixed tag or version, unless a check fails the build once it falls behind (like `linearis-npm`'s assertion). Release-branch refs (`26.05`) instead get a warning from `modules/nixos/base.nix` when they need bumping.
- A hardcoded hash is fine only when its source moves with a flake input, so a stale hash breaks the build (e.g. a Go `vendorHash`).
- Pin container images by digest, read from a registry-metadata flake input (like `foundryvtt-image`); a bare tag is pulled once and never again.
- Whatever still can't move with the flake (in-repo lockfiles) is covered by the flake-update skill's stale-pin review.

## Testing

- If you create a new file that must be visible to flakes, `git add` it before any build.
- Verify meaningful config changes before calling the work done.
- Default verification for NixOS changes is `just switch`. Don't use `test`: its generation is lost on reboot.
- Don't run `nh os switch` or `nixos-rebuild switch` yourself. They run activation under your shell, and restarting OpenCode or sshd kills it midway.

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
- `durin` is the primary desktop (formerly `am`).
- `gimli` is the laptop (formerly `torag`).
- `narvi` is the always-on server (formerly `balrog`).

## Update Reports

Especially if I mention something used to work there's a good chance it was broken by a recent update. The ./update-reports directory may already contain helpful info.

## Failures

known failures (hopefully mostly warnings) are tracked in failures.md
