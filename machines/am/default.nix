{
  nixModules =
    [
      ./hardware.nix
      # ./wifi.nix
    ];
  homeModules = [ ];
  ip = "192.168.1.6";
  drive = "/dev/nvme0n1";
  builder = true;
  wifi = {
    enable = true;
    interface = "wlp2s0f0u4";
  };
  battery = false;
  system = "x86_64-linux";
}
