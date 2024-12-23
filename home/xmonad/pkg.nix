{ pkgs, ... }:
{
  my-xmonad =
    pkgs.haskellPackages.developPackage {
      root = ./.;
      modifier = drv:
        pkgs.haskell.lib.addBuildTools drv
        [
          pkgs.haskellPackages.cabal-install
          pkgs.haskellPackages.haskell-language-server
          pkgs.xorg.libX11
          pkgs.xorg.libXrandr
          pkgs.xorg.libXScrnSaver
          pkgs.xorg.libXext
        ];
    };
}
