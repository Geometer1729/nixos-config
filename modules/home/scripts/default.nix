{ lib, pkgs, ... }:
{
  imports = [ ./module.nix ];

  scripts = lib.mapAttrs'
    (name: _: lib.nameValuePair (lib.removeSuffix ".sh" name) { })
    (lib.filterAttrs
      (name: type: type == "regular" && lib.hasSuffix ".sh" name)
      (builtins.readDir ./.)) // {
    # Enabled, with their dependencies, by the clipboard-history module.
    cliphist.enable = lib.mkDefault false;
    clipboard-history.enable = lib.mkDefault false;
    pinentry.extra = with pkgs; [ pinentry-qt pinentry-curses ];
    persist-survey.extra = with pkgs; [ util-linux ];
  };

  # Also install the shared dependencies globally for interactive use.
  home.packages = import ./dependencies.nix pkgs;
}
