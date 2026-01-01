{ pkgs, ... }:
{
  home.packages = with pkgs;
    (builtins.map
      (name: writeShellApplication
        {
          name = builtins.replaceStrings [ ".sh" ] [ "" ] name;
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
    # packages needed by scripts
    ++ [
      fzf
      jq
    ];
}

