{ flake, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;

  # Packages available to all scripts at runtime
  scriptDeps = with pkgs; [
    curl
    fzf
    gh
    git
    jq
    python3
    flake.inputs.mighty-rearranger.packages.${system}.default
    flake.inputs.mighty-rearranger.inputs.rageveil.packages.${system}.default
  ];
in
{
  home.packages = with pkgs;
    (map
      (name: writeShellApplication
        {
          name = builtins.replaceStrings [ ".sh" ] [ "" ] name;
          runtimeInputs = scriptDeps;
          runtimeEnv = {
            SCRIPTS_LIB = "${./lib}";
          };
          text = builtins.readFile ./${name};
          # Enable shellcheck to follow sourced files from lib/
          extraShellCheckFlags = [
            "--external-sources"
            "--source-path=${./lib}"
          ];
        }
      )
      (builtins.filter
        (name: name != "default.nix" && name != "lib")
        (builtins.attrNames (builtins.readDir ./.))
      )
    )
    # Also install these packages globally for interactive use
    ++ scriptDeps;
}
