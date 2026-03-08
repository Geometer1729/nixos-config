{ config, pkgs, ... }:
{
  nix = {
    settings = {
      # Explicitly set system features for remote building
      system-features = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      # Sign store paths so they're trusted by machines using am as a substituter
      secret-key-files = [ "/var/cache-priv-key.pem" ];
    };
    sshServe.enable = true;
  };

  # Enable nix-serve for binary cache
  services.nix-serve = {
    enable = true;
    port = 5000;
    secretKeyFile = "/var/cache-priv-key.pem";
  };

  # Open firewall for nix-serve
  networking.firewall.allowedTCPPorts = [ 5000 ];

  # Persist nix-serve keys with impermanence
  environment.persistence."/persist/system".files = [
    "/var/cache-priv-key.pem"
    "/var/cache-pub-key.pem"
  ];
}
