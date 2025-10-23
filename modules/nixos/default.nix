{ flake, config, lib, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{

  mainUser = "bbrian";
  nixos-unified.sshTarget = "${config.mainUser}@${config.networking.hostName}";
  system.stateVersion = "25.05";

  # Remove 90 second wait from rebuild ffs
  virtualisation.virtualbox.guest.enable = false;
  services.tcsd.enable = false;

  nixpkgs.overlays = lib.attrValues self.overlays;
  home-manager = {
    backupFileExtension = "bkp";
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      ${config.mainUser}.imports = [ (self + /configurations/home/bbrian.nix) ];
      root.imports = [ (self + /configurations/home/root.nix) ];
    };
  };

  imports =
    with self.nixosModules;
    [
      #inputs
      inputs.nur.modules.nixos.default
      inputs.disko.nixosModules.default
      inputs.impermanence.nixosModules.impermanence
      inputs.stylix.nixosModules.stylix
      inputs.sops-nix.nixosModules.sops
      #self
      boot
      bt
      disko
      gh-noto
      hyprland
      impermanence
      main
      nix
      secrets
      ssh
      steam
      stylix
      tailscale
      work
      wifi
      yubikey
    ];
}
