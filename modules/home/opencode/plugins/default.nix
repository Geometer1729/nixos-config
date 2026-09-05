{ lib, pkgs }:
let
  pluginPackage = import ./package.nix { inherit lib pkgs; };
  inherit (pluginPackage) sourceFiles;
  pluginFiles = builtins.filter (path: path != ./tui/vim-engine.ts) sourceFiles;
in
builtins.listToAttrs (map
  (source: {
    name = "opencode/plugins/${lib.removePrefix "${toString ./.}/" (toString source)}";
    value.source = "${pluginPackage.package}/${lib.removePrefix "${toString ./.}/" (toString source)}";
  })
  pluginFiles)
