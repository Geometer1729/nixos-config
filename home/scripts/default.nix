{ pkgs, ... }:
{
  home.packages = with pkgs;
    (builtins.map
      (name: writeShellApplication
        {
          name = builtins.replaceStrings [ ".sh" ] [ "" ] name;
          text = builtins.readFile ./${name};
        }
      )
      (builtins.filter
        (name: name != "default.nix")
        (builtins.attrNames (builtins.readDir ./.))
      )
    );
}

