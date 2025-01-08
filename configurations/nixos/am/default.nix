{flake,config,...}:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{

  networking.hostName = "am";
  amd = true;
  mainUser = "bbrian";
  drive = "/dev/nvme0n1";
  cloudflare-id = "3981fa82-1e49-4e4c-8df9-962a244d988a";
  system.stateVersion = "22.05";

  home-manager.users.${config.mainUser} = {
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
      cloudflare
      #just am
      home
    ];
}
