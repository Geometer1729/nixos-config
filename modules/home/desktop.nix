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

    # presentations
    presenterm

    # Documents
    libreoffice-fresh
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications."application/vnd.openxmlformats-officedocument.wordprocessingml.document" =
      "libreoffice-writer.desktop";
  };

  # Rofi configuration
  programs.rofi = {
    enable = true;
    terminal = "ghostty"; # not working
  };

  xdg.configFile."kwalletrc" = {
    force = true;
    text = ''
      [Wallet]
      Enabled=false
    '';
  };

  # Desktop services
  services = {
    systembus-notify.enable = true;
  };
}
