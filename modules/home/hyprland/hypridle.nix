{ lib, config, pkgs, ... }:
let
  # hypridle suspends by shelling out to `systemctl suspend`, so a logind block
  # inhibitor stops it without relying on hypridle noticing. Only sleep is
  # inhibited, so the screen still locks on the normal timeout.
  keepAwake = pkgs.writeShellScriptBin "keep-awake" ''
    set -euo pipefail

    duration="''${1:-24h}"
    host=$(${pkgs.coreutils}/bin/uname -n)

    # Replace any inhibitor already holding the machine awake
    ${pkgs.systemd}/bin/systemctl --user stop keep-awake.service 2>/dev/null || true

    if [ "$duration" = off ]; then
      echo "$host: normal idle behaviour restored"
      exit 0
    fi

    ${pkgs.systemd}/bin/systemd-run --user --quiet \
      --unit=keep-awake \
      --description="Block automatic suspend" \
      --collect \
      ${pkgs.systemd}/bin/systemd-inhibit \
        --what=sleep \
        --who=keep-awake \
        --why="keep-awake requested by $(${pkgs.coreutils}/bin/id -un)" \
        --mode=block \
        ${pkgs.coreutils}/bin/sleep "$duration"

    echo "$host will not suspend for $duration (cancel with: keep-awake off)"
  '';
in
{
  options.fast_lock = with lib; mkOption
    {
      type = types.bool;
      description = "faster locking";
      default = false;
    };

  config.home.packages = [ keepAwake ];

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
              on-timeout = "hyprlock";
            }
            # DPMS disabled - testing if monitor's own power saving is causing blackouts
            # {
            #   timeout = 90 * 60;
            #   on-timeout = "hyprctl dispatch dpms off";
            #   on-resume = "hyprctl dispatch dpms on";
            # }
            {
              timeout = 120 * 60;
              on-timeout = "sudo systemctl suspend";
            }
          ];
    };
  };
}
