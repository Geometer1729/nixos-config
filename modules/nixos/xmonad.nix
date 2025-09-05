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
        autoLogin = {
          enable = true;
          user = config.mainUser;
        };
        sessionCommands = ''
          feh --randomize --bg-fill ~/Pictures/Wallpapers/
        '';
      };
    };
  };
  console.useXkbConfig = true;
}
