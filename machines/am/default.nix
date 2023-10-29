{
  nixModules = [ ./hardware.nix ];
  homeModules = [ ];
  ip = "192.168.1.147";
  builder = true;
  wifi = false;
  battery = false;
  system = "x86_64-linux";
}
