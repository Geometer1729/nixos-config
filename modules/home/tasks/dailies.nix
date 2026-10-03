{ config, lib, ... }:
let
  cfg = config.tasks.dailies;
in
{
  options.tasks.dailies.enable = lib.mkEnableOption "creating daily tasks from the wiki's recur.md";

  config = lib.mkMerge [
    {
      programs.taskwarrior.config.uda.routine = {
        type = "string";
        label = "Routine";
      };
    }
    (lib.mkIf cfg.enable {
      systemd.user.services.task-dailies = {
        Unit = {
          Description = "Create today's daily tasks";
          After = [ "network-online.target" ];
        };
        Service = {
          Type = "oneshot";
          Environment = [ "TZ=America/New_York" ];
          ExecStart = "${config.scripts.tasks.packages.task-dailies}/bin/task-dailies";
        };
      };

      systemd.user.timers.task-dailies = {
        Unit.Description = "Create daily tasks after midnight";
        Timer = {
          OnCalendar = "*-*-* 01:00:00 America/New_York";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    })
  ];
}
