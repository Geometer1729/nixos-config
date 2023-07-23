{ pkgs, ... }:
{
    home.packages = with pkgs;
    [ wpa_supplicant
      wpa_supplicant_gui
    ];
}
