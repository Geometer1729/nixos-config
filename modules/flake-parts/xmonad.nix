{ inputs, ... }:
{
  imports = [
    inputs.haskell-flake.flakeModule
  ];
  perSystem = { lib, ... }: {
    haskellProjects.default = {
      projectRoot =
        let root = ../home/xmonad;
        in
        builtins.toString (lib.fileset.toSource {
          inherit root;
          fileset = lib.fileset.unions [
            (root + /lib)
            (root + /Main.hs)
            (root + /Config.hs)
            (root + /my-xmonad.cabal)
          ];
        });

      packages = { };

      settings = {
        my-xmonad = {
          stan = true;
          haddock = false;
        };
      };

      # Development shell configuration
      devShell = {
        hlsCheck.enable = false;
      };

      autoWire = [ "packages" "checks" ];
    };
  };
}
