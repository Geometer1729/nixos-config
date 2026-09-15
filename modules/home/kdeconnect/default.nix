{ config, lib, osConfig, ... }:
let
  devices = import ./devices.nix;
  peers = lib.filterAttrs (name: _: name != osConfig.networking.hostName) devices;
in
{
  services.kdeconnect.enable = true;

  systemd.user.services.kdeconnect.Unit.X-Restart-Triggers = [
    config.xdg.configFile."kdeconnect/config".source
    "${./plugins.conf}"
    "${./notifications.conf}"
  ];

  xdg.configFile = {
    "kdeconnect/config".text = lib.generators.toINI { } {
      General = {
        customDevices = lib.concatMapStringsSep ", " (peer: peer.address) (lib.attrValues peers);
        keyAlgorithm = "EC";
      };
    };
  } // lib.concatMapAttrs
    (_: peer: {
      "kdeconnect/${peer.id}/config".source = ./plugins.conf;
      "kdeconnect/${peer.id}/kdeconnect_sendnotifications/config".source = ./notifications.conf;
    })
    peers;
}
