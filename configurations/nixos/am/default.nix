{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{

  networking.hostName = "am";
  amd = true;
  drive = "/dev/nvme0n1";
  system.stateVersion = "22.05";


  imports = with self.nixosModules;
    [
      ./hardware.nix
      default
      home
    ];
}
