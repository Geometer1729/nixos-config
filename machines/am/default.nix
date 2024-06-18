{
  nixModules =
    [
      ./hardware.nix
      #./wifi.nix
    ];
  homeModules = [ ];
  ip = "10.144.25.173";
  drive = "/dev/nvme0n1";
  builder = true;
  wifi = {
    enable = false;
    interface = "wlp2s0f0u4";
  };
  battery = false;
  system = "x86_64-linux";
}
