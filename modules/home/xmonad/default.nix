{ flake, pkgs, lib, config, ... }:
{
  config.home.packages = with pkgs; [
    xorg.xev # x event viewer (sometimes needed for xmonad dev)
    xmonadctl # xmonad server mode control
    xdotool
    arandr # xrandr gui
  ];

  options.xrander = lib.mkOption {
    type = lib.types.string;
    description = "xrander commands to run in ./xinitrc";
    default = "";
  };

  config.home.file = {
    ".xinitrc".text = config.xrander + builtins.readFile ./xinit;
    ".xmonad/xmonad-x86_64-linux".onChange =
      "pgrep xmonad && xmonad --restart";
    # TODO find the xmobar config and restart on that too
    # There's an error with that
  };

  config.xsession.windowManager.xmonad =
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
