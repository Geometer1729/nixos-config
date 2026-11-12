{ flake, ... }:
final: prev:
let
  unstable = flake.inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system};
in
{
  # Hyprland 0.57 matches release binds against the mods held at press, so
  # letting go of Alt before E still stops dictation. Remove once nixpkgs
  # (26.11) ships 0.57.
  hyprland =
    final.lib.warnIf (final.lib.versionAtLeast prev.hyprland.version "0.57")
      "nixpkgs hyprland is ${prev.hyprland.version}; drop overlays/hyprland.nix"
      unstable.hyprland;
  # Keep the portal in sync with the compositor it talks to.
  inherit (unstable) xdg-desktop-portal-hyprland;
}
