{ userName, ... }:
{
  services.getty.autologinUser = userName;
  services.xserver = {
    enable = true;
    displayManager.startx.enable = true;
    windowManager.xmonad.enable = true;
    xkb.options = "caps:swapescape";
    xkb.layout = "us";
  };
  console.useXkbConfig = true;
}
