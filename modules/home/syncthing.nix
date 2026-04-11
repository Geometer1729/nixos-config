{ lib, config, osConfig, ... }:
let
  # Device configuration - add your device IDs here
  # Get device ID by running: syncthing device-id
  devices = {
    am = {
      id = "YFC525D-GUV3HTC-EPRRNPY-CRYYQCG-ANDWVZY-TXQAP36-GXQSB2J-YPJYEAF";
      addresses = [ "tcp://am:22000" ];
    };
    torag = {
      id = "3MB5CXC-4FO3G2D-YH4PF6X-DY2IGTN-R4YB5RI-GZPTKAK-K6IKHOQ-QBBWNQG";
      addresses = [ "tcp://torag:22000" ];
    };
  };

  # Remove current machine from device list
  otherDevices = lib.filterAttrs (name: _: name != osConfig.networking.hostName) devices;
in
{
  services.syncthing = {
    enable = true;

    settings = {
      devices = otherDevices;
      folders = {
        wiki = {
          path = "${config.home.homeDirectory}/Documents/vw";
          devices = builtins.attrNames otherDevices;
          ignorePerms = false;
          # Watch for changes to sync quickly
          fsWatcherEnabled = true;
        };
        pass = {
          path = "${config.home.homeDirectory}/password-store";
          devices = builtins.attrNames otherDevices;
          ignorePerms = false;
          # Watch for changes to sync quickly
          fsWatcherEnabled = true;
        };
      };

      options = {
        # Listen on local network for faster sync (Tailscale)
        localAnnounceEnabled = true;
        # Also use global discovery
        globalAnnounceEnabled = true;
        # Enable NAT traversal
        natEnabled = true;
        # Use relay servers as fallback
        relaysEnabled = true;
      };
    };
  };
}
