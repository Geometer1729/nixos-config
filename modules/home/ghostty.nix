{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      window-padding-x = 3;
      window-padding-y = 3;
      command = "${pkgs.tmux}/bin/tmux";
      window-theme = "ghostty";
      gtk-titlebar = false;
      confirm-close-surface = false;
      # io_uring waits on the pty count as IO wait, which fakes disk pressure
      # in PSI and top. epoll has no noticeable cost for a terminal.
      async-backend = "epoll";
    };
  };
}
