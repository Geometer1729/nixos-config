{ flake, config, lib, pkgs, ... }:
{
  scripts.nix = {
    directory = ./.;
    extras = [ config.nix.package pkgs.gh pkgs.python3 ];
    overrides.flake-update.extras = [
      config.scripts.nix.packages.flake-changelog
      config.scripts.nix.packages.nixpkgs-changelog
    ];
  };

  nix = {
    nixPath = [ "nixpkgs=${flake.inputs.nixpkgs}" ];

    package = lib.mkDefault pkgs.nixVersions.latest;
    settings = {
      substituters = [ "https://cache.nixos.org" "https://prismlauncher.cachix.org" "http://narvi:5000?priority=60&retry-attempts=1" ];
      trusted-substituters = [ "https://cache.nixos.org" "https://prismlauncher.cachix.org" "http://narvi:5000?priority=60&retry-attempts=1" ];
      # Fail fast when a LAN cache is offline instead of stalling every nix command
      connect-timeout = 3;
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "prismlauncher.cachix.org-1:9/n/FGyABA2jLUVfY+DEp4hKds/rwO+SCOtbOkDzd+c="
        "balrog:uh4ZkAwvEmgCQRz6Ihl3wPHL09RqO2e2uraO44olABI="
      ];
      warn-dirty = false;
      accept-flake-config = true;
      log-lines = 25;
      auto-optimise-store = false;
      experimental-features = [ "nix-command" "flakes" "recursive-nix" ];
      trusted-users = [ "root" config.mainUser ];
      keep-outputs = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 21d";
    };
  };

  # Builds and substitutions yield the CPU and disk to everything else. cgroup
  # weights only compete between siblings, so the daemon gets its own top-level
  # slice rather than a low weight inside system.slice. IOWeight also covers the
  # daemon's deferred writeback, and only BFQ enforces it.
  systemd.slices.background.sliceConfig = {
    CPUWeight = "idle";
    IOWeight = 10;
  };
  systemd.services.nix-daemon.serviceConfig.Slice = "background.slice";

  boot.kernelModules = [ "bfq" ];
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", KERNEL=="nvme[0-9]*n[0-9]*|sd[a-z]*", ATTR{queue/scheduler}="bfq"
  '';

  # Throttle heavy writers early instead of letting gigabytes of dirty pages
  # build up and stall every fsync when they flush.
  boot.kernel.sysctl = {
    "vm.dirty_background_bytes" = 64 * 1024 * 1024;
    "vm.dirty_bytes" = 256 * 1024 * 1024;
  };
}
