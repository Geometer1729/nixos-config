{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Communication apps
    discord
    whatsapp-for-linux
    element-desktop # matrix client
    signal-desktop
    # zoom-us # video calls
  ];
}
