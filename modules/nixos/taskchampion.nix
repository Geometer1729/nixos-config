{ config, lib, ... }:
{
  services.taskchampion-sync-server = {
    enable = true;
    host = "0.0.0.0"; # Listen on all interfaces (Tailscale will be accessible)
    port = 8888;
    openFirewall = true;
  };

  # Persist data if using impermanence
  environment.persistence."/persist/system" = lib.mkIf (config ? environment.persistence) {
    directories = [
      config.services.taskchampion-sync-server.dataDir
    ];
  };
}
