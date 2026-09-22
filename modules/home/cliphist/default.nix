{ config, lib, pkgs, ... }:
let
  cliphist = config.scripts.cliphist.packages.cliphist;
in
{
  scripts.cliphist = {
    directory = ./.;
    extras = with pkgs; [ pkgs.cliphist config.programs.rofi.package wl-clipboard python3 ];
    # The picker must use our runtime-only database wrapper before upstream cliphist.
    overrides.clipboard-history.extras = [ cliphist ];
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
