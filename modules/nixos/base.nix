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

  # Release-branch inputs stop moving once their release loses support. Unstable
  # jumps a second release ahead when the next one branches off, weeks before that.
  warnings =
    let
      stable = lib.trivial.release;
      unstable = inputs.nixpkgs-unstable.lib.trivial.release;
      year = lib.toIntBase10 (lib.versions.major stable);
      next = if lib.versions.minor stable == "05" then "${toString year}.11" else "${toString (year + 1)}.05";
    in
    lib.optional (lib.versionOlder next unstable)
      "nixpkgs ${stable} is about to lose support (unstable is ${unstable}): move every ${stable} ref in flake.nix to ${next}";

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
  # NSS 3.131.1 dropped the other emSign roots, and cacert fails on blocklisting absent roots.
  security.pki.caCertificateBlacklist = [
    "emSign Root CA - G1"
    "Comodo AAA Services root"
  ];

}
