{
  nixModules = [ ./hardware.nix ];
  homeModules = [ ];
  ip = "10.0.0.29";
  builder = false;
  wifi = true;
  system = "x86_64-linux";
}
