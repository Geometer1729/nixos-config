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
    balrog = {
      id = "DDE5AJ4-F7PSE7K-2Z7ZDQG-IBYGAMD-K2YIQ6X-POQJQZF-46SQ5MN-KZPHTAZ";
      addresses = [ "tcp://balrog:22000" ];
    };
  };

  # Remove current machine from device list
  otherDevices = lib.filterAttrs (name: _: name != osConfig.networking.hostName) devices;

  syncedFolder = path: {
    inherit path;
    type = lib.mkDefault "sendreceive";
    devices = builtins.attrNames otherDevices;
    ignorePerms = false;
    # Watch for changes to sync quickly
    fsWatcherEnabled = true;
    # Keep deleted/overwritten files around so a bad merge is recoverable
    versioning = {
      type = "staggered";
      params.maxAge = toString (90 * 24 * 60 * 60);
    };
  };
in
{
  services.syncthing = {
    enable = true;

    settings = {
      devices = otherDevices;
      folders = {
        documents = syncedFolder "${config.home.homeDirectory}/Documents";
        pictures = syncedFolder "${config.home.homeDirectory}/Pictures";
        memes = syncedFolder "${config.home.homeDirectory}/memes";
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

  # Syncthing reads this from the folder root; it is never synced itself.
  home.file."Documents/.stignore".text = ''
    // Git repos. Syncthing has no notion of merging divergent history, and
    // .git never converges byte-for-byte even when the working trees agree,
    // so it would manufacture conflicts forever. These travel over git.
    /P1-wiki
    /Spivak
    /paragore/paragore_vimwiki

    // direnv caches are symlinks into this machine's nix store, which are
    // dangling anywhere else.
    .direnv
  '';
}
