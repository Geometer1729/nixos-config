{
  nix.settings.secret-key-files = [ "/var/cache-priv-key.pem" ];

  services.nix-serve = {
    enable = true;
    port = 5000;
    secretKeyFile = "/var/cache-priv-key.pem";
  };

  networking.firewall.allowedTCPPorts = [ 5000 ];

  environment.persistence."/persist/system".files = [
    "/var/cache-priv-key.pem"
    "/var/cache-pub-key.pem"
  ];
}
