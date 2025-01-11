{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{

  networking.hostName = "am";
  amd = true;
  drive = "/dev/nvme0n1";
  cloudflare-id = "3981fa82-1e49-4e4c-8df9-962a244d988a";
  system.stateVersion = "22.05";


  imports = with self.nixosModules;
    [
      ./hardware.nix
      default
      home
    ];
}
