{ config, lib, ... }:
{
  # TODO why not "https://github.com/reckenrode/nix-foundryvtt"
  virtualisation.oci-containers.containers.foundryvtt = {
    image = "felddy/foundryvtt:release";
    ports = [ "127.0.0.1:30000:30000" ];
    volumes = [ "/var/lib/foundryvtt:/data" ];
    environmentFiles = [ config.sops.secrets.foundryvtt-env.path ];
    environment = {
      FOUNDRY_ROUTE_PREFIX = "foundry";
      FOUNDRY_PROXY_PORT = "80";
      FOUNDRY_PROXY_SSL = "false";
    };
  };

  # Ensure data directory has correct ownership for container (runs as 1000:1000)
  systemd.tmpfiles.rules = [ "d /var/lib/foundryvtt 0755 1000 1000 -" ];

  services.nginx.virtualHosts.default.locations = lib.genAttrs [ "= /foundry" "/foundry/" ]
    (_: {
      # Preserve the prefix: Foundry uses it for routes, assets, and Socket.IO.
      proxyPass = "http://127.0.0.1:30000";
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 300m;
        proxy_read_timeout 300s;
      '';
    });

  # Add restart delay so service waits for DNS if image needs pulling
  systemd.services.podman-foundryvtt.serviceConfig.RestartSec = "30s";

  # Persist Foundry data and container images across reboots
  environment.persistence."/persist/system" = lib.mkIf (config ? environment.persistence) {
    directories = [
      "/var/lib/foundryvtt"
      "/var/lib/containers"
    ];
  };
}
