{ lib, pkgs, ... }:
{
  imports = [ ./module.nix ];

  scripts = lib.mapAttrs'
    (name: _: lib.nameValuePair (lib.removeSuffix ".sh" name) { })
    (lib.filterAttrs
      (name: type: type == "regular" && lib.hasSuffix ".sh" name)
      (builtins.readDir ./.));

  # Also install the shared dependencies globally for interactive use.
  home.packages = import ./dependencies.nix pkgs;
}
