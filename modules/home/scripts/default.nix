{ config, lib, pkgs, ... }:
let
  # Packages available to all scripts at runtime
  scriptDeps = with pkgs; [
    coreutils
    curl
    fzf
    gh
    git
    jq
    libnotify
    pipewire
    pulseaudioFull
    python3
    systemd
  ];
in
{
  options.scripts = lib.mkOption {
    description = "Shell scripts to package and install; machine configs can enable, disable, or add scripts.";
    default = { };
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to install the ${name} script.";
        };
        source = lib.mkOption {
          type = lib.types.path;
          description = "Shell source for the ${name} script.";
        };
        runtimeInputs = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Additional packages available to the ${name} script at runtime.";
        };
      };
    }));
  };

  config = {
    scripts = lib.mapAttrs'
      (name: _: lib.nameValuePair (lib.removeSuffix ".sh" name) {
        source = lib.mkDefault ./${name};
      })
      (lib.filterAttrs
        (name: type: type == "regular" && lib.hasSuffix ".sh" name)
        (builtins.readDir ./.));

    home.packages =
      (lib.mapAttrsToList
        (name: script: pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = scriptDeps ++ script.runtimeInputs;
          runtimeEnv.SCRIPTS_LIB = "${./lib}";
          text = builtins.readFile script.source;
          # Enable shellcheck to follow sourced files from lib/
          extraShellCheckFlags = [
            "--external-sources"
            "--source-path=${./lib}"
          ];
        })
        (lib.filterAttrs (_: script: script.enable) config.scripts))
      # Also install these packages globally for interactive use
      ++ scriptDeps;
  };
}
