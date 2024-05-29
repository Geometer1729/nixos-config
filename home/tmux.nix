{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins;
      [
        vim-tmux-navigator
        yank
        plumb
        (
          let name = "themepack"; in
          mkTmuxPlugin {
            inherit name;
            pluginName = name;
            src = pkgs.fetchFromGitHub
              {
                repo = "tmux-" + name;
                owner = "jimeh";
                rev = "7c59902f64dcd7ea356e891274b21144d1ea5948";
                sha256 = "sha256-c5EGBrKcrqHWTKpCEhxYfxPeERFrbTuDfcQhsUAbic4=";
              };
          }
        )
        (
          let name = "resurrect"; in
          mkTmuxPlugin {
            inherit name;
            pluginName = name;
            src = pkgs.fetchFromGitHub
              {
                repo = "tmux-" + name;
                owner = "tmux-plugins";
                rev = "cff343cf9e81983d3da0c8562b01616f12e8d548";
                sha256 = "sha256-FcSjYyWjXM1B+WmiK2bqUNJYtH7sJBUsY2IjSur5TjY=";
              };
          }
        )
        (
          let name = "continuum"; in
          mkTmuxPlugin {
            inherit name;
            pluginName = name;
            src = pkgs.fetchFromGitHub
              {
                repo = "tmux-" + name;
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
    keyMode = "vi";
    extraConfig =
      ''
        # better splits
        unbind %
        bind h split-window -v
        unbind '"'
        bind v split-window -h

        bind a attach-session -c "#{pane_current_path}" \; rename-session "#{pane_current_path}" \; new-window

        set-option -g @tmux-autoreload-configs '/home/bbrian/.config/tmux/tmux.conf'

        #continuum settings
        set -g @resurrect-capture-pane-contents 'on'
        set -g @continuum-resore 'on'
        # this doesn't seem to work
        set -g @resurrect-strategy-nvim 'session'
        set -g @resurrect-strategy-vim 'session'

        # Only enable status when there is more than one window
        # from https://schauderbasis.de/posts/hide_tmux_status_bar_if_its_not_needed/
        set -g status off
        set-hook -g after-new-window      'if "[ #{session_windows} -gt 1 ]" "set status on"'
        set-hook -g after-kill-pane       'if "[ #{session_windows} -lt 2 ]" "set status off"'
        set-hook -g pane-exited           'if "[ #{session_windows} -lt 2 ]" "set status off"'
        set-hook -g window-layout-changed 'if "[ #{session_windows} -lt 2 ]" "set status off"'

        set -g default-terminal tmux-256color

        # Fixes escape being slow in vim (when in tmux)
        set -sg escape-time 0
      '';
  };
}
