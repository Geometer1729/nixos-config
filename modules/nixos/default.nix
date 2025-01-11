{flake,config,...}:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{

  mainUser = "bbrian";
  system.stateVersion = "22.05";

  home-manager.users.${config.mainUser} = {
    imports = [ (self + /configurations/home/bbrian.nix) ];
  };
  home-manager.users.root = {
    imports = [ (self + /configurations/home/root.nix) ];
  };

  imports =
    with self.nixosModules;
    [
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
      impermanence
      ssh
      stylix
      wifi
      work
      xmonad
      main
      cloudflare
    ];
}
