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
          # TODO does stylix set this?
          #greeters.gtk.theme.name = "Arc-Dark";
        };
        autoLogin = {
          enable = true;
          user = config.mainUser;
        };
        sessionCommands = ''
          xrandr --output HDMI-1 --mode 2560x1440 --rate 60 --primary
          xrandr --output DP-2 --mode 1920x1080 --rate 60 --right-of HDMI-1
          feh --randomize --bg-fill ~/Pictures/Wallpapers/ &
        '';
      };
    };
  };
  console.useXkbConfig = true;
}
