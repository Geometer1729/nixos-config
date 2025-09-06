{ config, ... }:
{
  services.getty.autologinUser = config.mainUser;
  services = {
    xserver = {
      enable = true;
      windowManager.xmonad.enable = true;
      xkb.options = "caps:swapescape";
      xkb.layout = "us";
      displayManager = {
        lightdm = {
          enable = true;
        };
        sessionCommands = ''
          feh --randomize --bg-fill ~/Pictures/Wallpapers/
        '';
      };
    };
    displayManager.autoLogin = {
      enable = true;
      user = config.mainUser;
    };
  };
  console.useXkbConfig = true;
}
