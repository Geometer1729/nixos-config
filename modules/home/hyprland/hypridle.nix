{ pkgs, lib, config, ... }:
{
  options.fast_lock = with lib; mkOption
    {
      type = types.bool;
      description = "faster locking";
      default = false;
    };
  config.services.hypridle = {
    enable = true;
    settings = {
      general = {
        after_sleep_cmd = "hyprctl dispatch dpms on; bluetooth-autoconnect.sh";
        before_sleep_cmd = "hyprlock";
        ignore_dbus_inhibit = false;
        lock_cmd = "hyprlock";
      };

      listener =
        if config.fast_lock
        then
          [
            {
              timeout = 10 * 60;
              on-timeout = "hyprlock";
            }
            {
              timeout = 15 * 60;
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = "hyprctl dispatch dpms on";
            }
            {
              timeout = 20 * 60;
              on-timeout = "sudo systemctl suspend";
            }
          ]
        else
          [
            {
              timeout = 60 * 60;
              on-timeout = "hyprlock";
            }
            {
              timeout = 90 * 60;
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = "hyprctl dispatch dpms on";
            }
            {
              timeout = 120 * 60;
              on-timeout = "sudo systemctl suspend";
            }
          ];
    };
  };
}
