{ lib, config, ... }:
let
  # Device configuration - add your device IDs here
  # Get device ID by running: syncthing device-id
  devices = {
    am = {
      id = "F5YLCSQ-AKXGXGH-3RVAGUA-BDMCMUT-DZ3NPWW-HGUV4Z7-ZNT7AV4-XLQCEAP";
      addresses = [ "tcp://am:22000" ];
    };
    torag = {
      id = "AZD3HDE-KTIG5P3-RBNVCPE-4IZH2E5-CHJXWBV-UTOUD63-ZYH4YEC-55ZXEAK";
      addresses = [ "tcp://torag:22000" ];
    };
  };

  # Get the current hostname to filter out self
  hostname = config.networking.hostName or (builtins.getEnv "HOSTNAME");

  # Remove current machine from device list
  otherDevices = lib.filterAttrs (name: _: name != hostname) devices;
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
