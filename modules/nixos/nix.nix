{ flake, config, pkgs, ... }:
{
  nix = {
    nixPath = [ "nixpkgs=${flake.inputs.nixpkgs}" ];

    package = pkgs.nixVersions.latest;
    #package = flake.inputs.nix.packages."x86_64-linux".nix;
    settings = {
      substituters = [ "https://cache.nixos.org" ];
      trusted-substituters = [ "https://cache.nixos.org" ];
      trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
      warn-dirty = false;
      #accept-flake-config = true;
      log-lines = 25;
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" "ca-derivations" "recursive-nix" ];
      trusted-users = [ "root" config.mainUser ];
      keep-outputs = true;
    };
    gc = {
      automatic = true;
      options = "--delete-older-than 21d";
      # cleans up old home-manager genrations
      dates = "weekly";
    };
  };
}
