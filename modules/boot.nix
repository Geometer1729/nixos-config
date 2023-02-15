{ config, pkgs, ... }:
{
  boot= {
    cleanTmpDir = true;
    loader = {
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot/efi";
      #systemd-boot.enable = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 20;
      };
    };
  };

}
