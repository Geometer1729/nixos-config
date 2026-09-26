{ config, pkgs, ... }:
let
  inherit (config.scripts.systemd-failures) packages;
in
{
  # Simple systemd failure notification via periodic checking
  # Checks every 5 minutes for failed services and sends notifications
  # Clicking a notification hands the failures to OpenCode in ~/conf.

  scripts.systemd-failures = {
    directory = ./.;
    extras = [ config.programs.opencode.package pkgs.mako ];
  };

  services.mako.settings."app-name=systemd-failures".on-button-left =
    "exec ${packages.opencode-failure}/bin/opencode-failure \"$id\"";

  systemd.user.services.check-failed-services = {
    Unit = {
      Description = "Check for failed systemd services and notify";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${packages.check-failed-services}/bin/check-failed-services";
    };
  };

  systemd.user.timers.check-failed-services = {
    Unit = {
      Description = "Check for failed services every 5 minutes";
    };
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
