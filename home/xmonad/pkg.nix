{ pkgs, ... }:
{
  my-xmonad =
    pkgs.haskellPackages.developPackage {
      root = ./.;
      modifier = drv:
        pkgs.haskell.lib.addBuildTools drv (with pkgs.haskellPackages;
        [
          cabal-install
          haskell-language-server
        ]);
    };
}
