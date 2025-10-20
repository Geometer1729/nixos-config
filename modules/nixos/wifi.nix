{ config, pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  networking.wireless = {
    enable = true;
    interfaces = [ "wlp0s20f3" ];
    secretsFile = config.sops.secrets.wifi.path;
    extraConfig = ''
      ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel
      update_config=1
    '';
    networks =
      lib.attrsets.foldAttrs (l: r: l) { }
        (
          builtins.map (name: { ${name}.pskRaw = "ext:${name}"; })
            [
              "My love"
              "the_dojo"
              "ASUS"
              "WiliamHowardTaftMemorialNetwork"
              "FASBOOKS WIFI_5GEXT"
              "binaup"
              "WhiteSky-Slate"
              "moria"
            ]
        );
  };
  environment.systemPackages = with pkgs;
    [
      wpa_supplicant
      wpa_supplicant_gui
    ];
}
