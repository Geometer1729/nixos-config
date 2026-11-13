{ config, lib, ... }:
{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts.default.default = true;
  };

  security.acme.acceptTerms = true;

  # Keep certs and the ACME account; reissuing on every boot hits Let's Encrypt rate limits.
  environment.persistence."/persist/system" = lib.mkIf (config ? environment.persistence) {
    directories = [
      { directory = "/var/lib/acme"; user = "acme"; group = "acme"; mode = "0755"; }
    ];
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
