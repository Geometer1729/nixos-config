{ config, ... }:
{
  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
  services.blueman.enable = true;

  home-manager.users.${config.mainUser} = { pkgs, ... }: {
    scripts.bluetooth = {
      directory = ./.;
      extras = with pkgs; [ bluez blueman ];
    };
  };
}
