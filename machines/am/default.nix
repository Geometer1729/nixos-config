{
  nixModules = [ ./hardware.nix ];
  homeModules = [ ];
  ip = "192.168.1.147";
  builder = true;
  wifi = true;
  battery = false;
  system = "x86_64-linux";
}
