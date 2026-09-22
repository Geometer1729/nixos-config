{ lib, config, pkgs, ... }:
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
        before_sleep_cmd = "loginctl lock-session";
        ignore_dbus_inhibit = false;
        # Wait for the compositor to confirm the session is locked before sleeping.
        inhibit_sleep = 3;
        # Keep manually started lockers; systemd owns new ones independently.
        lock_cmd = "pgrep -x hyprlock || ${pkgs.systemd}/bin/systemctl --user start hyprlock.service";
      };

      listener =
        if config.fast_lock
        then
          [
            {
              timeout = 10 * 60;
              on-timeout = "loginctl lock-session";
            }
            # DPMS disabled - testing if monitor's own power saving is causing blackouts
            # {
            #   timeout = 15 * 60;
            #   on-timeout = "hyprctl dispatch dpms off";
            #   on-resume = "hyprctl dispatch dpms on";
            # }
            {
              timeout = 20 * 60;
              on-timeout = "sudo systemctl suspend";
            }
          ]
        else
          [
            {
              timeout = 60 * 60;
              on-timeout = "loginctl lock-session";
            }
            # DPMS disabled - testing if monitor's own power saving is causing blackouts
            # {
            #   timeout = 90 * 60;
            #   on-timeout = "hyprctl dispatch dpms off";
            #   on-resume = "hyprctl dispatch dpms on";
            # }
            {
              timeout = 60 * 60;
              on-timeout = "sudo systemctl suspend";
            }
          ];
    };
  };
}
