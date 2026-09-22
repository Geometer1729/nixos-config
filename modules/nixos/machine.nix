{ config, lib, ... }:
{
  options = {
    mainUser = lib.mkOption {
      type = lib.types.str;
      default = "bbrian";
      description = "Primary user of the system";
    };
    machine.hasGui = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether this machine provides a graphical desktop environment";
    };
  };

  config._module.args.machine = config.machine;
  config.home-manager.extraSpecialArgs.machine = config.machine;
}
