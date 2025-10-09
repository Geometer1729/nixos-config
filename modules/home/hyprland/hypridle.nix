{ pkgs, ... }:
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        after_sleep_cmd = "hyprctl dispatch dpms on; bluetooth-autoconnect.sh";
        before_sleep_cmd = "hyprlock";
        ignore_dbus_inhibit = false;
        lock_cmd = "hyprlock";
      };

      listener = [
        {
          timeout = 10 * 60;
          # TODO 5 minutes on laptop
          on-timeout = "hyprlock";
        }
        {
          timeout = 15 * 60; # 10 minutes
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };
}
