{ flake, config, pkgs, ... }:
{
  nix = {
    nixPath = [ "nixpkgs=${flake.inputs.nixpkgs}" ];

    package = pkgs.nixVersions.latest;
    settings = {
      substituters = [ "https://cache.nixos.org" "https://prismlauncher.cachix.org" "http://balrog:5000" ];
      trusted-substituters = [ "https://cache.nixos.org" "https://prismlauncher.cachix.org" "http://balrog:5000" ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "prismlauncher.cachix.org-1:9/n/FGyABA2jLUVfY+DEp4hKds/rwO+SCOtbOkDzd+c="
        "balrog:uh4ZkAwvEmgCQRz6Ihl3wPHL09RqO2e2uraO44olABI="
      ];
      warn-dirty = false;
      accept-flake-config = true;
      log-lines = 25;
      max-jobs = 12;
      auto-optimise-store = false;
      experimental-features = [ "nix-command" "flakes" "recursive-nix" ];
      trusted-users = [ "root" config.mainUser "yixin" ];
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
