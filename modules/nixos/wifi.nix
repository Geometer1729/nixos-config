{ config, pkgs, lib, ... }:
let
  cfg = config.wifi;
in
{
  options.wifi = {
    enable = lib.mkOption {
      type = lib.types.bool;
      description = "Enable wifi support";
      default = false;
    };
    interface = lib.mkOption {
      type = lib.types.str;
      description = "Wifi interface name";
      default = "wlp0s20f3";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.wireless = {
      enable = true;
      interfaces = [ cfg.interface ];
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
  };
}
