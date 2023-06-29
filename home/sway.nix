{ config, pkgs, lib, ... }:
{
  wayland.windowManager.sway ={
    enable = true;
    #wrapperFeatures.base = true;
    wrapperFeatures.gtk =true;
    config = {
      modifier = "Mod1";
      terminal = "alacritty";
      startup = [
        { command = ''
          sway output HDMI-A-1 pos 0 0
        '';
        }
      ];
    };
    extraConfig = ''
      input "type:keyboard" {
        xkb_options caps:swapescape
      }
    '';
    # TODO can this inherit from xkb config like console?
  };

}
