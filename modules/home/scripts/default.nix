{ lib, pkgs, ... }:
{
  imports = [ ./module.nix ];

  scripts = lib.mapAttrs'
    (name: _: lib.nameValuePair (lib.removeSuffix ".sh" name) { })
    (lib.filterAttrs
      (name: type: type == "regular" && lib.hasSuffix ".sh" name)
      (builtins.readDir ./.)) // {
    pinentry.extra = with pkgs; [ pinentry-qt pinentry-curses ];
  };

  # Also install the shared dependencies globally for interactive use.
  home.packages = import ./dependencies.nix pkgs;
}
