{ config, lib, ... }:
{
  imports = [ ./module.nix ];

  home.packages = lib.concatMap
    (group: lib.mapAttrsToList (name: _: group.packages.${name})
      (lib.filterAttrs (_: script: script.enable) group.overrides))
    (lib.filter (group: group.enable) (lib.attrValues config.scripts));
}
