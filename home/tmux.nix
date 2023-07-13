{pkgs,...}:
{
  programs.tmux={
    enable = true;
    plugins = with pkgs.tmuxPlugins;
      [catppuccin
       vim-tmux-navigator
      ];
    mouse = true;
    keyMode="vi";
    extraConfig =
      ''
      '';
  };
}
