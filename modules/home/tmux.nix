{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins;
      [
        vim-tmux-navigator
        yank
        plumb
      ];
    mouse = true;
    keyMode = "vi";
    extraConfig =
      ''
        # Send prefix to nested tmux with double press
        bind C-b send-prefix

        # better splits
        unbind %
        bind h split-window -v
        unbind '"'
        bind v split-window -h

        bind g popup -h 90% -w 90% 'EDITOR=nvim lazygit'
        bind a rename-session "#{b:pane_current_path}"
        set-hook -g session-renamed 'attach-session -c "#{pane_current_path}"'

        set-option -g @tmux-autoreload-configs '/home/bbrian/.config/tmux/tmux.conf'

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

        bind u send-keys C-l \; run-shell "sleep .5s" \; clear-history
      '';
  };
}
