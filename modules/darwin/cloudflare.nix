{ config, pkgs, lib, ... }:

{
  options.cloudflare-id = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    description = "the id of the cloudflare tunnel for this machine";
    default = null;
  };

  config = lib.mkIf (config.cloudflare-id != null) {
    # Install cloudflared package
    environment.systemPackages = [ pkgs.cloudflared ];

    # Create launchd service for cloudflared tunnel
    launchd.daemons.cloudflared = {
      serviceConfig = {
        Label = "com.cloudflare.cloudflared.${config.cloudflare-id}";
        ProgramArguments = [
          "${pkgs.cloudflared}/bin/cloudflared"
          "tunnel"
          "--config"
          "/etc/cloudflared/config.yml"
          "run"
          config.cloudflare-id
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/var/log/cloudflared.log";
        StandardErrorPath = "/var/log/cloudflared.log";
      };
    };

    # Create configuration directory and file
    environment.etc."cloudflared/config.yml".text = ''
      tunnel: ${config.cloudflare-id}
      credentials-file: /etc/cloudflared/cert.json
      
      ingress:
        - service: http_status:404
    '';
  };
}
