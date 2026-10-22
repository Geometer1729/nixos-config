{ flake, config, lib, pkgs, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    inputs.disko.nixosModules.default
    inputs.impermanence.nixosModules.impermanence
    inputs.stylix.nixosModules.stylix
    inputs.sops-nix.nixosModules.sops
  ] ++ (with self.nixosModules; [
    boot
    disko
    impermanence
    keep-awake
    key-help
    machine
    nix
    password
    resume-timers
    scripts
    secrets
    ssh
    storage-health
    stylix
    tailscale
  ]);

  nixpkgs = {
    overlays = lib.attrValues self.overlays;
    config.allowUnfree = true;
  };
  hardware.enableRedistributableFirmware = true;

  # Every deploy builds the config devshell and keeps it alive with the generation.
  system.extraDependencies = [ self.devShells.${pkgs.stdenv.hostPlatform.system}.default ];

  home-manager = {
    backupFileExtension = "bkp";
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${config.mainUser}.imports = [ (self + /configurations/users/bbrian.nix) ];
  };

  users.users.${config.mainUser} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
  };
  programs.zsh.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # eMudhra intermediate keys were trivially weak (Mozilla bug 2083449); AAA was the Sectigo cross-sign path.
  security.pki.caCertificateBlacklist = [
    "emSign Root CA - G1"
    "emSign ECC Root CA - G3"
    "emSign Root CA - C1"
    "emSign ECC Root CA - C3"
    "Comodo AAA Services root"
  ];

}
