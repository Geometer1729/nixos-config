{
  nixModules =
    [ ./hardware.nix
      ./hosting.nix
    ];
  homeModules = [ ];
  ip = "192.168.1.176";
  builder = true;
  wifi = {
    enable = true;
    interface = "wlp2s0f0u5";
  };
  battery = false;
  system = "x86_64-linux";
}
