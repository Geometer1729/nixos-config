{ config, lib, pkgs, ... }:
let
  cliphist = config.scripts.cliphist.package;
in
{
  imports = [ ./scripts ];

  scripts = {
    cliphist = {
      enable = true;
      extra = [ pkgs.cliphist ];
    };
    clipboard-history = {
      enable = true;
      extra = [ cliphist config.programs.rofi.package pkgs.wl-clipboard ];
    };
  };

  services.cliphist = {
    enable = true;
    package = cliphist;
    allowImages = true;
    systemdTargets = [ "hyprland-session.target" ];
    extraOptions = [ ];
  };

  # The upstream module's first watcher is untyped, overlapping the image one.
  systemd.user.services.cliphist.Service.ExecStart = lib.mkForce
    "${lib.getExe' pkgs.wl-clipboard "wl-paste"} --type text --watch ${lib.getExe cliphist} store";

  xdg.configFile."cliphist/config".text = ''
    max-items 500
    max-dedupe-search 100
    preview-width 1000
  '';
}
