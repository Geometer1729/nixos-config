{ flake, config, lib, ... }:
let
  release = builtins.fromJSON (builtins.readFile flake.inputs.foundryvtt-image);
in
{
  # TODO why not "https://github.com/reckenrode/nix-foundryvtt"
  virtualisation.oci-containers.containers.foundryvtt = {
    # Pinned by digest so `nix flake update` moves it; a bare tag is pulled once and never again.
    image = "docker.io/felddy/foundryvtt@${release.digest}";
    # Foundry binds its license signature to the hostname; podman otherwise randomizes it per start.
    hostname = "foundryvtt";
    ports = [ "127.0.0.1:30000:30000" ];
    volumes = [ "/var/lib/foundryvtt:/data" ];
    environmentFiles = [ config.sops.secrets.foundryvtt-env.path ];
    environment = {
      FOUNDRY_ROUTE_PREFIX = "foundry";
      FOUNDRY_PROXY_PORT = "443";
      FOUNDRY_PROXY_SSL = "true";
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
