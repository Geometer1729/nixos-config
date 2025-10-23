{ config, pkgs, lib, ... }:
{
  # Simple systemd failure notification via periodic checking
  # Checks every 5 minutes for failed services and sends notifications

  systemd.user.services.check-failed-services = {
    Unit = {
      Description = "Check for failed systemd services and notify";
    };
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "check-failed" ''
        # Check user services
        FAILED_USER=$(${pkgs.systemd}/bin/systemctl --user list-units --state=failed --no-legend --plain | ${pkgs.gawk}/bin/awk '{print $1}' | ${pkgs.gnugrep}/bin/grep -v '^$')
        if [ -n "$FAILED_USER" ]; then
          ${pkgs.libnotify}/bin/notify-send -u critical "Failed User Services" "$FAILED_USER"
        fi

        # Check system services
        FAILED_SYSTEM=$(${pkgs.systemd}/bin/systemctl list-units --state=failed --no-legend --plain 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $1}' | ${pkgs.gnugrep}/bin/grep -v '^$')
        if [ -n "$FAILED_SYSTEM" ]; then
          ${pkgs.libnotify}/bin/notify-send -u critical "Failed System Services" "$FAILED_SYSTEM"
        fi
      '';
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
