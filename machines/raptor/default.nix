{
  nixModules =
    [ ./hardware.nix
      ./home-assistant.nix
    ];
  homeModules = [ ];
  ip = "192.168.1.106";
  builder = false;
  wifi = {
    enable = true;
    interface = "wlp3s0";
  };
  battery = true;
  system = "x86_64-linux";
}
