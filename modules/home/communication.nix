{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Communication apps
    discord
    wasistlos # Whatsapp
    element-desktop # matrix client
    signal-desktop
    # zoom-us # video calls
  ];
}
