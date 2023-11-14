{
  nixModules = [ ./hardware.nix ];
  homeModules = [ ];
  ip = "192.168.1.109";
  builder = false;
  wifi = {
    enable = true;
    interface = "wlp3s0";
  };
  battery = true;
  system = "x86_64-linux";
}
