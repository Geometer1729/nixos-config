{ ... }:
{
  boot= {
    tmp.cleanOnBoot = true;
    loader = {
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot/efi";
      systemd-boot = {
        enable = true;
        configurationLimit = 20;
      };
    };
  };

}
