{pkgs,...}:
{
  programs.tmux={
    enable = true;
    plugins = with pkgs.tmuxPlugins;
      [ vim-tmux-navigator
        yank
        plumb
        ( let name = "themepack"; in
          mkTmuxPlugin {
            inherit name;
            pluginName = name;
            src = pkgs.fetchFromGitHub
              { repo= "tmux-" + name;
                owner = "jimeh";
                rev = "7c59902f64dcd7ea356e891274b21144d1ea5948";
                sha256 = "sha256-c5EGBrKcrqHWTKpCEhxYfxPeERFrbTuDfcQhsUAbic4=";
              };
          }
        )
        ( let name = "resurrect"; in
          mkTmuxPlugin {
            inherit name;
            pluginName = name;
            src = pkgs.fetchFromGitHub
              { repo= "tmux-" + name;
                owner = "tmux-plugins";
                rev = "cff343cf9e81983d3da0c8562b01616f12e8d548";
                sha256 = "sha256-FcSjYyWjXM1B+WmiK2bqUNJYtH7sJBUsY2IjSur5TjY=";
              };
          }
        )
        ( let name = "continuum"; in
          mkTmuxPlugin {
            inherit name;
            pluginName = name;
            src = pkgs.fetchFromGitHub
              { repo= "tmux-" + name;
                owner = "tmux-plugins";
                rev = "3e4bc35da41f956c873aea716c97555bf1afce5d";
                sha256 = "sha256-Z10DPP5svAL6E8ZETcosmj25RkA1DTBhn3AkJ7TDyN8=";
              };
          }
        )
        # Doesn't seem to work
        #(
        #  mkTmuxPlugin {
        #    name = "autoreload";
        #    pluginName = "tmux-autoreload";
        #    rtpFilePath = "tmux-autoreload.tmux";
        #    src = pkgs.fetchFromGitHub
        #      { repo= "tmux-autoreload";
        #        owner = "b0o";
        #        rev = "e98aa3b74cfd5f2df2be2b5d4aa4ddcc843b2eba";
        #        sha256 = "sha256-9Rk+VJuDqgsjc+gwlhvX6uxUqpxVD1XJdQcsc5s4pU4=";
        #      };
        #  }
        #)
      ];
    mouse = true;
    keyMode="vi";
    extraConfig =
      ''
      set -g pane-active-border-style fg=cyan
      #set -g pane-border-style fg=cyan

      # better splits
      unbind %
      bind h split-window -v
      unbind '"'
      bind v split-window -h

      set-option -g @tmux-autoreload-configs '/home/bbrian/.config/tmux/tmux.conf'

      #continuum settings
      set -g @resurrect-capture-pane-contents 'on'
      set -g @continuum-resore 'on'
      # this doesn't seem to work
      set -g @resurrect-strategy-nvim 'session'
      set -g @resurrect-strategy-vim 'session'
      '';
  };
}
