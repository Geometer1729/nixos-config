{
  nixModules =
    [
      ./hardware.nix
    ];
  homeModules = [ ];
  ip = "10.144.176.131";
  builder = true;
  drive = "/dev/nvme0n1";
  wifi = {
    enable = true;
    interface = "wlp3s0";
  };
  battery = true;
  system = "x86_64-linux";
}
