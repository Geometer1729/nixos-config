{
  nixModules =
    [ ./hardware.nix
      ./hosting.nix
      ./wifi.nix
    ];
  homeModules = [ ];
  ip = "192.168.1.176";
  builder = true;
  wifi = {
    enable = true;
    interface = "wlp13s0f3u2";
  };
  battery = false;
  system = "x86_64-linux";
}
