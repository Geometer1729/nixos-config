{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Fonts
    font-awesome
    fira-mono
    noto-fonts-emoji

    # Desktop environment tools
    dunst # notification manager for xorg
    libnotify # notify-send

    # Input device configuration
    piper
    libratbag
  ];

  # Rofi configuration
  programs.rofi = {
    enable = true;
    pass.enable = true;
    terminal = "alacritty"; # not working
  };

  # Desktop services
  services = {
    dunst.enable = true;
    systembus-notify.enable = true;
    picom = {
      enable = true;
      vSync = true;
    };

    # Screenshots
    flameshot = {
      enable = false; # gives an annoying notification and doesn't work on wayland
      settings = {
        General = {
          #this breaks something now?
          #savePath = "/home/bbrian/Downloads/";
          showHelp = false;
          uiColor = "#0ce3ff";
          contrastOpacity = 188;
          buttons = # magic string from gui config editor
            ''
              @Variant(\0\0\0\x7f\0\0\0\vQList<int>\0\0\0\0\v\0\0\0\0\0\0\0\x1\0\0\0\x2\0\0\0\x3\0\0\0\x4\0\0\0\x5\0\0\0\x6\0\0\0\x12\0\0\0\b\0\0\0\n\0\0\0\v)
            '';
        };
      };
    };
  };
}
