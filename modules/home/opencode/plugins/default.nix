{ lib, pkgs }:
let
  pluginPackage = import ./package.nix { inherit lib pkgs; };
  inherit (pluginPackage) sourceFiles;
  # Link whole plugin directories: OpenCode resolves index.ts / tui.tsx, and
  # requires their real paths to remain inside the plugin's real directory.
  targets = lib.unique (map
    (source: builtins.head (lib.splitString "/" (lib.removePrefix "${toString ./.}/" (toString source))))
    sourceFiles);
in
builtins.listToAttrs (map
  (target: {
    name = "opencode/plugins/${target}";
    value.source = "${pluginPackage.package}/${target}";
  })
  targets)
