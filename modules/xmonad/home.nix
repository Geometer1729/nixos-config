{ config, pkgs, lib, ... }:
  let
    my-xmonad =
    ((import ./pkg.nix)
    {inherit config pkgs lib;}
    ).my-xmonad  ;
  in
{
  home.file.".xinitrc".source = ./xinit;

  home.file.".xmonad/xmonad-x86_64-linux".onChange = "xmonad --restart";

  xsession.windowManager.xmonad =
    { enable = true;
      enableContribAndExtras = true;
      config = ./my-xmonad/Main.hs;
      extraPackages = haskellPackages : with haskellPackages ;
        [ my-xmonad
          extra
        ];
    };
}
