{ ... }:
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
      env.TERM = "xterm-256color";
      shell.program = "tmux";
    };
  };
}
