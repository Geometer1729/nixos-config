{ flake, lib, pkgs, ... }:
let
  inherit (flake) inputs;
  keys = import ../../../ssh-authorized-keys.nix;
in
{
  imports = [
    inputs.disko.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.impermanence.nixosModules.impermanence
    inputs.stylix.nixosModules.stylix
    inputs.self.nixosModules.boot
    inputs.self.nixosModules.cache
    inputs.self.nixosModules.disko
    inputs.self.nixosModules.impermanence
    inputs.self.nixosModules.machine
    inputs.self.nixosModules.stylix
    inputs.self.nixosModules.taskchampion
    inputs.self.nixosModules.useBuilders
    ./hardware.nix
  ];

  networking.hostName = "balrog";
  networking.useDHCP = true;
  hardware.enableRedistributableFirmware = true;
  machine.hasGui = false;

  nixpkgs.overlays = lib.attrValues inputs.self.overlays;
  nixpkgs.config.allowUnfree = true;

  home-manager = {
    backupFileExtension = "bkp";
    useGlobalPkgs = true;
    useUserPackages = true;
    users.bbrian = {
      imports = [ (inputs.self + /configurations/home/bbrian.nix) ];
      programs.git.signing.signByDefault = lib.mkForce false;
    };
  };

  # Samsung SSD 860 EVO 250GB, serial S3YHNX0KB88921Z.
  drive = "/dev/disk/by-id/wwn-0x5002538e40a0ae76";

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  systemd.services.tailscale-reset-prefs = {
    description = "Apply declarative Tailscale preferences";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Initial tailnet authentication is intentionally interactive.
      if ! ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
        exit 0
      fi
      ${pkgs.tailscale}/bin/tailscale up --reset \
        --ssh \
        --accept-routes \
        --accept-dns \
        --operator=bbrian
    '';
  };

  users.users.root = {
    hashedPassword = "!";
    openssh.authorizedKeys.keys = keys;
  };
  users.users.bbrian = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPassword = "!";
    linger = true;
    openssh.authorizedKeys.keys = keys;
    shell = pkgs.zsh;
  };
  security.sudo.wheelNeedsPassword = false;
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [ git tailscale tmux vim wakeonlan ];
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      max-jobs = 2;
      trusted-users = [ "root" "bbrian" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 21d";
    };
  };

  system.stateVersion = "26.05";
}
