{ pkgs, ... }:
{
  # rofi launcher configuration
  programs.rofi = {
    enable = true;

    extraConfig = {
      modi = "drun,ssh,run";
      show-icons = true;
      terminal = "alacritty";
      drun-display-format = "{icon} {name}";
      location = 0;
      disable-history = false;
      hide-scrollbar = true;
      display-drun = "   Apps ";
      display-run = "   Run ";
      display-ssh = "   SSH ";
      sidebar-mode = true;
    };
  };
}
