{ pkgs, ... }:
{
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      splash_offset = 2.0;

      # You can set wallpapers here - adjust paths as needed
      preload = [
        "~/Pictures/wallpaper.jpg"
      ];

      wallpaper = [
        "HDMI-A-1,~/Pictures/wallpaper.jpg"
        "DP-2,~/Pictures/wallpaper.jpg"
      ];
    };
  };
}
