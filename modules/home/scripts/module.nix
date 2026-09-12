{ config, lib, pkgs, ... }:
let
  defaults = import ./dependencies.nix pkgs;
in
{
  options.scripts = lib.mkOption {
    description = "Shell scripts from this directory to package and install by name.";
    default = { };
    type = lib.types.attrsOf (lib.types.submodule ({ name, config, ... }: {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to install the ${name} script.";
        };
        extra = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Extra runtime packages for the ${name} script, appended to the shared defaults.";
        };
        package = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          description = "Built package for the ${name} script, for use in services and other scripts.";
        };
      };

      config.package = pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = defaults ++ config.extra;
        runtimeEnv.SCRIPTS_LIB = "${./lib}";
        text = builtins.readFile ./${name}.sh;
        # Enable shellcheck to follow sourced files from lib/
        extraShellCheckFlags = [
          "--external-sources"
          "--source-path=${./lib}"
        ];
      };
    }));
  };

  config.home.packages = lib.mapAttrsToList (_: script: script.package)
    (lib.filterAttrs (_: script: script.enable) config.scripts);
}
