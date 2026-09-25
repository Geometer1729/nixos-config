{ config, lib, ... }:
{
  # rofi launcher configuration
  programs.rofi = {
    enable = true;

    extraConfig = {
      modi = "combi,drun,ssh,run,keybinds:${lib.getExe config.scripts.hyprland.packages.rofi-keybinds} ${config.programs.waybar.clickActions}";
      combi-modes = "drun,ssh,run,keybinds";
      combi-display-format = "{mode}: {text}";
      show-icons = true;
      terminal = "ghostty";
      drun-display-format = "{icon} {name}";
      location = 0;
      disable-history = false;
      hide-scrollbar = true;
      display-combi = "   ALL ";
      display-drun = "   Apps ";
      display-run = "   Run ";
      display-ssh = "   SSH ";
      display-keybinds = "   Keybinds ";
      sidebar-mode = true;
    };
  };
}
