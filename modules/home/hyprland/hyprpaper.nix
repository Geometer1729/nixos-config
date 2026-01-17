{ pkgs, config, ... }:
{
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      splash_offset = 2;

      # You can set wallpapers here - adjust paths as needed
      preload = [
        "/home/bbrian/Pictures/Wallpapers/purpleSpace.jpg"
      ];

      wallpaper = [
        "HDMI-A-1,/home/bbrian/Pictures/Wallpapers/purpleSpace.jpg"
        "DP-1,/home/bbrian/Pictures/Wallpapers/purpleSpace.jpg"
      ];
    };
  };

  # Override the systemd service to explicitly pass the config file
  systemd.user.services.hyprpaper = {
    Service = {
      ExecStart = pkgs.lib.mkForce "${pkgs.hyprpaper}/bin/hyprpaper --config ${config.xdg.configHome}/hypr/hyprpaper.conf";
    };
  };
}
