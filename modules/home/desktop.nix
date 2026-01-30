{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Fonts
    font-awesome
    noto-fonts-color-emoji

    # Desktop environment tools
    libnotify # notify-send

    # Input device configuration
    piper
    libratbag

    #browser
    ungoogled-chromium
  ];

  # Rofi configuration
  programs.rofi = {
    enable = true;
    pass.enable = true;
    terminal = "alacritty"; # not working
  };

  # Desktop services
  services = {
    systembus-notify.enable = true;
  };
}
