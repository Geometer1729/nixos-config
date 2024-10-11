{
  nixModules =
    [
      ./hardware.nix
    ];
  homeModules = [ ];
  ip = "10.144.176.137";
  builder = true;
  drive = "/dev/nvme0n1";
  wifi = {
    enable = true;
    interface = "wlp0s20f3";
  };
  battery = true;
  system = "x86_64-linux";
  amd = false;
}
