{ lib, machine, pkgs, ... }:
let
  defaults = with pkgs; [
    coreutils
    curl
    diffutils
    findutils
    gawk
    git
    gnugrep
    gnused
    jq
    openssh
    procps
    systemd
    util-linux
  ] ++ lib.optional machine.hasGui pkgs.libnotify;
in
{
  options.scripts = lib.mkOption {
    description = "Locally owned groups of shell scripts to package and install.";
    default = { };
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }:
      let
        group = config;
        entries = builtins.readDir group.directory;
        library = group.directory + "/lib";
        hasLibrary = (entries.lib or null) == "directory";
      in
      {
        options = {
          directory = lib.mkOption {
            type = lib.types.path;
            description = "Directory containing this group's top-level .sh files.";
          };
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to install this group; its packages remain available when disabled.";
          };
          extras = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            description = "Runtime packages shared by this group, in addition to the standard script toolbox.";
          };
          runtimeEnv = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Environment variables shared by this group's wrappers.";
          };
          extraShellCheckFlags = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Additional ShellCheck flags, including paths for sourced libraries.";
          };
          overrides = lib.mkOption {
            default = { };
            description = "Optional per-command settings; discovered scripts need no entry.";
            type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
              options = {
                source = lib.mkOption {
                  type = lib.types.path;
                  default = group.directory + "/${name}.sh";
                  description = "Shell source for ${name}; override to rename a command or use another file.";
                };
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to install ${name} when the group is enabled.";
                };
                extras = lib.mkOption {
                  type = lib.types.listOf lib.types.package;
                  default = [ ];
                  description = "Additional runtime packages, placed before the group's extras in PATH.";
                };
                runtimeEnv = lib.mkOption {
                  type = lib.types.attrsOf lib.types.str;
                  default = { };
                  description = "Environment variables overriding or extending the group's runtimeEnv.";
                };
                extraShellCheckFlags = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "ShellCheck flags appended to the group's flags.";
                };
              };
            }));
          };
          packages = lib.mkOption {
            type = lib.types.attrsOf lib.types.package;
            readOnly = true;
            description = "Built packages by command name, including disabled commands.";
          };
        };

        config = {
          overrides = lib.mapAttrs'
            (name: _: lib.nameValuePair (lib.removeSuffix ".sh" name) { })
            (lib.filterAttrs
              (name: type: type == "regular" && lib.hasSuffix ".sh" name)
              entries);

          packages = lib.mapAttrs
            (name: script: pkgs.writeShellApplication {
              inherit name;
              runtimeInputs = lib.unique (script.extras ++ group.extras ++ defaults);
              runtimeEnv = lib.optionalAttrs hasLibrary { SCRIPTS_LIB = "${library}"; }
                // group.runtimeEnv // script.runtimeEnv;
              extraShellCheckFlags = lib.optionals hasLibrary [
                "--external-sources"
                "--source-path=${library}"
              ] ++ group.extraShellCheckFlags ++ script.extraShellCheckFlags;
              text = builtins.readFile script.source;
            })
            group.overrides;
        };
      }));
  };
}
