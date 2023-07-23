{ secrets, pkgs, userName, opts, ... }:
if !opts.wifi then {} else
{
  networking.wireless = {
      enable = true;
      networks.epicGamerWifi.psk=secrets.wifi;
    };
  environment.systemPackages = with pkgs;
    [ wpa_supplicant
      wpa_supplicant_gui
    ];
}
