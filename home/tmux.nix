{pkgs,...}:
{
  programs.tmux={
    enable = true;
    plugins = with pkgs.tmuxPlugins;
      [ vim-tmux-navigator
        yank
      ];
    mouse = true;
    keyMode="vi";
    extraConfig =
      ''
      '';
  };
}
