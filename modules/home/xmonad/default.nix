{ pkgs, config, ... }:
let
  isRoot = config.home.username == "root";
  my-xmonad =
    ((import ./pkg.nix)
      { inherit pkgs; }
    ).my-xmonad;
in
{
  home.file = {
    ".xinitrc".source = ./xinit;
  } //
  (if isRoot
  then { }
  # don't restart xmonad while root
  # it fails because root has no xsession
  else {
    ".xmonad/xmonad-x86_64-linux".onChange =
      "pgrep xmonad && xmonad --restart";
    # TODO find the xmobar config and restart on that too
  }
  );

  xsession.windowManager.xmonad =
    {
      enable = true;
      enableContribAndExtras = true;
      config = ./Main.hs;
      extraPackages = haskellPackages: with haskellPackages ;
        [
          my-xmonad
          extra
        ];
    };
}
