{ userName, ... }:
{
  services.getty.autologinUser = userName;
  services.xserver = {
    layout = "us";
    enable = true;
    displayManager.startx.enable=true;
    windowManager.xmonad.enable=true;
    xkbOptions = "caps:swapescape";
  };
  console.useXkbConfig = true;
  hardware.opengl.enable = true;
}
