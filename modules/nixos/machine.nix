{ config, lib, ... }:
{
  options.machine.hasGui = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether this machine provides a graphical desktop environment";
  };

  config.home-manager.extraSpecialArgs.machine = config.machine;
}
