{ config, pkgs, ... }:
{
  # Configure nix-daemon to have cloudflared in PATH
  systemd.services.nix-daemon = {
    path = [ pkgs.cloudflared ];
  };

  nix = {
    settings = {
      builders-use-substitutes = true;
      # Add am as a substitute server
      substituters = [ "http://am.nix-store.bbrian.xyz" ];
      trusted-substituters = [ "http://am.nix-store.bbrian.xyz" ];
    };
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "am";
        sshKey = "/home/${config.mainUser}/.ssh/id_ed25519";
        sshUser = config.mainUser;
        system = "x86_64-linux";
        # Match exactly what the builder machine supports
        supportedFeatures = [ "benchmark" "big-parallel" "kvm" "nixos-test" ];
        mandatoryFeatures = [ ];
        # Increase speed setting to prefer remote builder
        speedFactor = 2;
      }
    ];
  };
}
