{
  nixModules =
    [
      ./hardware.nix
    ];
  homeModules = [ ];
  ip = "10.144.176.131";
  builder = false;
  drive = "/dev/nvme0n1";
  wifi = {
    enable = true;
    interface = "wlp0s20f3";
  };
  battery = true;
  system = "x86_64-linux";
  amd = false;
}
