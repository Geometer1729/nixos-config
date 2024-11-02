{ ... }:
{
  wayland.windowManager.sway = {
    enable = true;
    #wrapperFeatures.base = true;
    wrapperFeatures.gtk = true;
    config = {
      modifier = "Mod2";
      terminal = "alacritty";
      startup = [
        {
          command = ''
            sway output HDMI-A-1 pos 0 0
            exec steam
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
