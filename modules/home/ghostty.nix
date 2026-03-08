{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      window-padding-x = 3;
      window-padding-y = 3;
      initial-command = "${pkgs.tmux}/bin/tmux";
      window-theme = "ghostty";
      gtk-titlebar = false;
      confirm-close-surface = false;
    };
  };
}
