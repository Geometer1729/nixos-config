{ config, pkgs, ... }:
let
  inherit (config.scripts.dependabot-alerts) packages;
in
{
  # Hourly check for open Dependabot alerts, notifying once per boot per alert.
  # Clicking a notification hands the alerts to OpenCode in ~/conf.

  scripts.dependabot-alerts = {
    directory = ./.;
    extras = [ config.programs.gh.package config.programs.opencode.package pkgs.mako ];
    runtimeEnv.DEPENDABOT_REPOS = "Geometer1729/nixos-config";
  };

  services.mako.settings."app-name=dependabot-alerts".on-button-left =
    "exec ${packages.opencode-dependabot}/bin/opencode-dependabot \"$id\"";

  systemd.user.services.check-dependabot-alerts = {
    Unit = {
      Description = "Check for open Dependabot alerts and notify";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${packages.check-dependabot-alerts}/bin/check-dependabot-alerts";
    };
  };

  systemd.user.timers.check-dependabot-alerts = {
    Unit = {
      Description = "Check for Dependabot alerts hourly";
    };
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
