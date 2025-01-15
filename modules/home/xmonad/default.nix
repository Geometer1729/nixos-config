{ flake, pkgs, config, ... }:
let
  isRoot = config.home.username == "root";
in
{
  home.file = {
    ".xinitrc".source = ./xinit;
    ".xmonad/xmonad-x86_64-linux".onChange =
      "pgrep xmonad && xmonad --restart";
    # TODO find the xmobar config and restart on that too
    # There's an error with that
  };

  xsession.windowManager.xmonad =
    {
      enable = true;
      enableContribAndExtras = true;
      config = ./Main.hs;
      extraPackages = haskellPackages: with haskellPackages ;
        [
          flake.inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.my-xmonad
          extra
        ];
    };
}
