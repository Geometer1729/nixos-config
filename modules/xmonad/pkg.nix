{ pkgs, ... }:
{
  my-xmonad =
    pkgs.haskellPackages.developPackage {
      root = ./my-xmonad;
      modifier = drv:
        pkgs.haskell.lib.addBuildTools drv (with pkgs.haskellPackages;
          [ cabal-install
            ghcid
            haskell-language-server
          ]);
    };
}
