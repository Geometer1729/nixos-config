{ pkgs, ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        padding = {
          x = 3;
          y = 3;
        };
      };
      # Small delay to fix Wayland initialization race condition
      # Issue only occurs on wayland + tmux
      # you just get a % from zsh before the prompt
      # Only happens on 2nd+ tmux sesions probably because tmux is slower the first time
      terminal.shell = "${pkgs.writeShellScript "tmux-delayed" ''
        sleep 0.02
        exec tmux
      ''}";
    };
  };
}
