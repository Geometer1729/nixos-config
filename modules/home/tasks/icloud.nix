{ pkgs, lib, config, ... }:
let
  # Python environment with iCloud support
  pythonWithICloud = pkgs.python3.withPackages (ps: with ps; [
    pyicloud
  ]);

  # Import reminders from iCloud Drive files
  icloud-import = pkgs.writeShellApplication {
    name = "icloud-import";
    runtimeInputs = [ pythonWithICloud pkgs.taskwarrior3 ];
    text = ''
      ${pythonWithICloud}/bin/python3 ${./icloud-import.py} "$@"
    '';
  };
in
{

  options.icloud-tasks = lib.mkEnableOption "enable icloud sync";

  config = lib.mkIf config.icloud-tasks {
    home.packages = with pkgs;
      [
        icloud-import
      ];

    # Systemd service for iCloud import (replaces the old sync)
    systemd.user.services.icloud-import = {
      Unit = {
        Description = "Import reminders from iCloud Drive to Taskwarrior";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${icloud-import}/bin/icloud-import";
      };
    };

    # Systemd timer for automatic import
    systemd.user.timers.icloud-import = {
      Unit = {
        Description = "Timer for iCloud reminders import";
      };
      Timer = {
        OnBootSec = "2min";
        OnUnitActiveSec = "5min";
        Persistent = true;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
