{ config, lib, osConfig, pkgs, ... }:
{
  home.packages = lib.optionals osConfig.machine.hasGui [ pkgs.anki-bin ];

  services.syncthing.settings.folders.anki = {
    path = "${config.home.homeDirectory}/.local/share/Anki2";
    devices = builtins.attrNames config.services.syncthing.settings.devices;
    type = if osConfig.machine.hasGui then "sendreceive" else "receiveonly";
    ignorePerms = false;
    fsWatcherEnabled = true;
    versioning = {
      type = "staggered";
      params.maxAge = toString (90 * 24 * 60 * 60);
    };
  };
}
