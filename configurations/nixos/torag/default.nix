{flake,config,pkgs,...}:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  inherit (pkgs) lib;
  system = "x86_64-linux";
in
{

  mainUser = "bbrian";
  drive = "/dev/nvme0n1";

  home-manager.users.${config.mainUser} = {
    wifi = {
      enable = true;
      interface = "wlp0s20f3";
    };
    battery = true;
    imports = [ (self + /configurations/home/bbrian.nix) ];
  };
  home-manager.users.root = {
    imports = [ (self + /configurations/home/root.nix) ];
  };

  imports =
    with self.nixosModules;
    [ #hardware
      ./hardware.nix
      #inputs
      inputs.disko.nixosModules.default
      inputs.impermanence.nixosModules.impermanence
      inputs.stylix.nixosModules.stylix
      inputs.sops-nix.nixosModules.sops
      #self
      secrets
      boot
      bt
      builder
      disko
      dns
      impermanence
      ssh
      stylix
      wifi
      work
      xmonad
      main
    ];
}
