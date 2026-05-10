{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Communication apps
    discord
    element-desktop # matrix client
    signal-desktop
    # zoom-us # video calls
  ];
}
