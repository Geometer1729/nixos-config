{ config, pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  options.cloudflare-id = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    description = "the id of the cloudflare tunnel for this machine";
    default = null;
  };
  config.services = {
    cloudflare-warp.enable = true;
    cloudflared = lib.mkIf (config.cloudflare-id != null)
      {
        enable = true;
        tunnels = {
          ${config.cloudflare-id} = {
            credentialsFile = "/etc/cloudflared-cert.json";
            default = "http_status:404";
          };
        };
      };
  };
}
