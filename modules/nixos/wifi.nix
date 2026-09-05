{ config, pkgs, lib, ... }:
let
  cfg = config.wifi;
  wifiPicker = pkgs.writeShellApplication {
    name = "wifi-picker";
    runtimeInputs = with pkgs; [
      coreutils
      fzf
      gawk
      gnugrep
      libnotify
      wpa_supplicant
    ];
    runtimeEnv.WIFI_INTERFACE = cfg.interface;
    text = builtins.readFile ./wifi-picker.sh;
  };
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
    users.users.${config.mainUser}.extraGroups = [ "wpa_supplicant" ];
    users.users.yixin.extraGroups = [ "wpa_supplicant" ];
    networking.wireless = {
      enable = true;
      interfaces = [ cfg.interface ];
      secretsFile = config.sops.secrets.wifi.path;
      userControlled = true;
      networks =
        lib.attrsets.foldAttrs (l: _r: l) { }
          (
            map (name: { ${name}.pskRaw = "ext:${name}"; })
              [
                "My love"
                "the_dojo"
                "ASUS"
                "WiliamHowardTaftMemorialNetwork"
                "FASBOOKS WIFI_5GEXT"
                "binaup"
                "WhiteSky-Slate"
                "moria"
                "Rina Wirelss 5g"
              ]
          );
    };
    programs.captive-browser = {
      enable = true;
      inherit (cfg) interface;
      browser = ''
        env XDG_CONFIG_HOME="$PREV_CONFIG_HOME" ${pkgs.brave}/bin/brave \
          --user-data-dir="''${XDG_DATA_HOME:-$HOME/.local/share}/brave-captive" \
          --proxy-server="socks5://$PROXY" \
          --host-resolver-rules="MAP * ~NOTFOUND , EXCLUDE localhost" \
          --no-first-run \
          --test-type \
          --new-window \
          --incognito \
          --no-default-browser-check \
          http://cache.nixos.org/
      '';
    };
    environment.systemPackages = with pkgs;
      [
        wpa_supplicant
        wifiPicker
      ];
  };
}
