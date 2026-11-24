{ config, lib, machine, pkgs, ... }:
let
  inherit (config.scripts.systemd-failures) packages;
  uda = label: { type = "string"; inherit label; };
in
{
  # Every 5 minutes on every host, each failed unit becomes a Taskwarrior task
  # (see check-failed-services.sh). Desktops also get a popup; clicking it opens
  # an OpenCode session on those tasks through opencode-start.

  programs.taskwarrior.config.uda = {
    # Space-separated <host>/<scope>/<unit>/<InvocationID>, one per failure seen.
    failure = uda "Failures";
    failurehost = uda "Failed host";
    failurescope = uda "Failed scope";
    failureunit = uda "Failed unit";
  };

  scripts.systemd-failures = {
    directory = ./.;
    extras = [ config.programs.taskwarrior.package ];
    runtimeEnv = lib.optionalAttrs machine.hasGui { FAILURE_NOTIFY = "1"; };
    overrides.opencode-failure = {
      enable = machine.hasGui;
      extras = [ config.scripts.opencode-launch.packages.opencode-start pkgs.mako ];
    };
  };

  services.mako.settings = lib.mkIf machine.hasGui {
    "app-name=systemd-failures".on-button-left =
      "exec ${packages.opencode-failure}/bin/opencode-failure \"$id\"";
  };

  systemd.user.services.check-failed-services = {
    Unit = {
      Description = "File tasks for failed systemd units, and notify";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${packages.check-failed-services}/bin/check-failed-services";
    };
  };

  systemd.user.timers.check-failed-services = {
    Unit = {
      Description = "Check for failed units every 5 minutes";
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
