{ pkgs, ... }:
  let
    my-xmonad =
    ((import ./pkg.nix)
    {inherit pkgs;}
    ).my-xmonad  ;
  in
{
  home.file = {
    ".xinitrc".source = ./xinit;
    ".xmonad/xmonad-x86_64-linux".onChange = "xmonad --restart";
  };

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
