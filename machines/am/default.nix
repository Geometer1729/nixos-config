{
  nixModules = [ ./hardware.nix ];
  homeModules = [ ];
  ip = "10.0.0.248";
  builder = true;
  wifi = false;
  system = "x86_64-linux";
}
