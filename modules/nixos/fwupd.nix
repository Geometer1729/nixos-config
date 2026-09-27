{ config, lib, ... }:
{
  config = lib.mkIf config.services.fwupd.enable {
    # Calendar timers can fire on resume before DNS/network connectivity returns.
    # network-online.target only synchronizes startup, not resume.
    systemd.services.fwupd-refresh = {
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "30s";
      };
      unitConfig = {
        StartLimitIntervalSec = "10min";
        StartLimitBurst = 5;
      };
    };
  };
}
