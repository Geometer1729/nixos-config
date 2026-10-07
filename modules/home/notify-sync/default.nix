# Mirrors notifications between desktops. Each host mirrors only the
# notifications that originate on it, over an SSH-forwarded peer session bus.
{ lib, osConfig, pkgs, ... }:
let
  desktops = [ "am" "torag" ];
  peers = lib.remove osConfig.networking.hostName desktops;

  notify-sync = pkgs.writers.writePython3Bin "notify-sync"
    {
      libraries = [ pkgs.python3Packages.dbus-fast ];
      flakeIgnore = [ "E501" ];
    }
    (builtins.readFile ./notify-sync.py);

  # bbrian has the same uid everywhere, so the peer's bus is at our own %t/bus.
  socket = peer: "%t/notify-sync-${peer}.bus";

  units = peer: {
    "notify-sync-tunnel-${peer}" = {
      Unit.Description = "Forward ${peer}'s session bus for notify-sync";
      Service = {
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.openssh}/bin/ssh -N"
          "-o BatchMode=yes"
          "-o ExitOnForwardFailure=yes"
          "-o ServerAliveInterval=10"
          "-o ServerAliveCountMax=3"
          "-o StreamLocalBindUnlink=yes"
          "-L ${socket peer}:%t/bus"
          peer
        ];
        Restart = "always";
        RestartSec = 10;
      };
      Install.WantedBy = [ "default.target" ];
    };

    "notify-sync-${peer}" = {
      Unit = {
        Description = "Mirror notifications to ${peer}";
        Wants = [ "notify-sync-tunnel-${peer}.service" ];
      };
      Service = {
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe notify-sync)
          "--peer unix:path=${socket peer}"
          "--makoctl ${pkgs.mako}/bin/makoctl"
          # These run on every desktop already.
          "--ignore slack"
          "--ignore discord"
        ];
        Restart = "always";
        RestartSec = 10;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
in
{
  # A click on a mirror can't reach the app, so it only dismisses (both copies).
  services.mako.settings."desktop-entry=notify-sync".on-button-left = "dismiss";

  systemd.user.services = lib.mergeAttrsList (map units peers);
}
