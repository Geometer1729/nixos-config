{ config, pkgs, lib, userName, ... }:
{
    programs.ssh = {
      enable = true;
      matchBlocks = {
        am = {
          hostname = "10.0.0.248";
          user = userName;
          identityFile = "~/.ssh/id_ed25519";
        };
      };
    };
    home.packages = with pkgs;
    [ wpa_supplicant
      wpa_supplicant_gui
    ];
}
