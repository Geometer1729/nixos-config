{
  nixModules = [ ./hardware.nix ];
  homeModules = [ ];
  ip = "192.168.1.109";
  builder = false;
  wifi = true;
  battery = true;
  system = "x86_64-linux";
}
