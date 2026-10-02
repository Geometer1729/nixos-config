{ config, lib, ... }:
let
  sleepTargets = [
    "suspend.target"
    "hibernate.target"
    "hybrid-sleep.target"
    "suspend-then-hibernate.target"
  ];
in
{
  scripts.resume-timers = {
    directory = ./.;
    enable = false;
  };

  # Sleep targets are reached only after resume, once their start jobs no longer
  # conflict with units started by Persistent timer catch-up.
  systemd.services.restart-failed-timers = {
    description = "Restart timers that failed to fire on resume";
    wantedBy = sleepTargets;
    after = sleepTargets;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe config.scripts.resume-timers.packages.restart-failed-timers;
    };
  };
}
