{ config, lib, ... }:
{
  virtualisation.oci-containers.containers.foundryvtt = {
    image = "felddy/foundryvtt:release";
    ports = [ "30000:30000" ];
    volumes = [ "/var/lib/foundryvtt:/data" ];
    environmentFiles = [ config.sops.secrets.foundryvtt-env.path ];
  };

  # Ensure data directory has correct ownership for container (runs as 1000:1000)
  systemd.tmpfiles.rules = [ "d /var/lib/foundryvtt 0755 1000 1000 -" ];

  # Open firewall port for internet access
  networking.firewall.allowedTCPPorts = [ 30000 ];

  # Persist Foundry data across reboots
  environment.persistence."/persist/system" = lib.mkIf (config ? environment.persistence) {
    directories = [ "/var/lib/foundryvtt" ];
  };
}
