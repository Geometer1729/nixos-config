{flake,config,...}:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{

  networking.hostName = "torag";
  drive = "/dev/nvme0n1";
  cloudflare-id = "9f53e225-4287-4c83-8049-b25f792cd1e0";

  home-manager.users.${config.mainUser} = {
    wifi = {
      enable = true;
      interface = "wlp0s20f3";
    };
    battery = true;
  };

  imports =
    with self.nixosModules;
    [ #hardware
      ./hardware.nix
      default
      useBuilders
    ];
}
