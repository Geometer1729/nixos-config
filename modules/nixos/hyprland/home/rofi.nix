{ config, lib, ... }:
{
  # rofi launcher configuration
  programs.rofi = {
    enable = true;

    extraConfig = {
      modi = "drun,ssh,run,keybinds:${lib.getExe config.scripts.hyprland.packages.rofi-keybinds}";
      show-icons = true;
      terminal = "ghostty";
      drun-display-format = "{icon} {name}";
      location = 0;
      disable-history = false;
      hide-scrollbar = true;
      display-drun = "   Apps ";
      display-run = "   Run ";
      display-ssh = "   SSH ";
      display-keybinds = "   Keybinds ";
      sidebar-mode = true;
    };
  };
}
