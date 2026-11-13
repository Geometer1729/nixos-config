{ flake, ... }:
final: prev:
let
  unstable = flake.inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system};
in
{
  # Stable nixpkgs lags far behind upstream gh-stack releases; unstable tracks
  # them and moves with `nix flake update`. Remove once stable catches up.
  gh-stack =
    final.lib.warnIf (final.lib.versionAtLeast prev.gh-stack.version unstable.gh-stack.version)
      "nixpkgs gh-stack is ${prev.gh-stack.version}; drop overlays/gh-stack.nix"
      unstable.gh-stack;
}
