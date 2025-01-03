{ config,pkgs, ... }:
{
  networking.wireless = {
    enable = true;
    extraConfig = ''
      ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel
      update_config=1
    '';
    secretsFile = config.sops.secrets.wifi.path;
  };
  environment.systemPackages = with pkgs;
    [
      wpa_supplicant
      wpa_supplicant_gui
    ];
}
