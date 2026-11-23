{ flake, ... }:
final: prev:
let
  unstable = flake.inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system};
in
{
  # tmux 3.7 blanks emoji written with U+FE0F (the prompt's 🏎️ and ❄️) in any
  # pane that doesn't start at the window's left edge; 3.8 fixed it. Unstable
  # moves with `nix flake update`. Remove once stable reaches 3.8.
  tmux =
    final.lib.warnIf (final.lib.versionAtLeast prev.tmux.version "3.8")
      "nixpkgs tmux is ${prev.tmux.version}; drop overlays/tmux.nix"
      unstable.tmux;
}
