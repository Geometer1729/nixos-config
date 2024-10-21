{ ... }:
{
  boot = {
    kernel.sysctl = {
      "vm.overcommit_memory" = 2;
      "vm.overcommit_ratio" = 100;
    };
    tmp.cleanOnBoot = true;
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 20;
      };
    };
  };
}
