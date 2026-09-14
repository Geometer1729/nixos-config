{ config, lib, osConfig, pkgs, ... }:
let
  preferencesPath = "${config.home.homeDirectory}/.local/share/Anki2/addons21/nixos_preferences/__init__.py";
  preferencesAddon = pkgs.writeText "anki-nixos-preferences.py" ''
    from aqt import gui_hooks, mw


    def disable_update_checks():
        if mw.pm.check_for_updates():
            mw.pm.set_update_check(False)
            mw.pm.save()


    gui_hooks.profile_did_open.append(disable_update_checks)
  '';
in
{
  home.packages = lib.optionals osConfig.machine.hasGui [ pkgs.anki-bin ];

  # Regular files remain portable when Syncthing copies the add-on between hosts.
  home.activation.ankiPreferences = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! ${pkgs.diffutils}/bin/cmp -s ${preferencesAddon} ${lib.escapeShellArg preferencesPath}; then
      run ${pkgs.coreutils}/bin/install -D -m 644 ${preferencesAddon} ${lib.escapeShellArg preferencesPath}
    fi
  '';

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
