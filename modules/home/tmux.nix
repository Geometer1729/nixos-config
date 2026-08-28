{ config, pkgs, ... }:
let
  resurrect = pkgs.tmuxPlugins.resurrect;
  saveTmux = pkgs.writeShellApplication {
    name = "save-tmux";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gawk
      gnugrep
      gnused
      procps
      tmux
    ];
    text = ''
      if tmux has-session 2>/dev/null; then
        ${resurrect}/share/tmux-plugins/resurrect/scripts/save.sh quiet
      fi
    '';
  };
in
{
  programs.tmux = {
    enable = true;
    secureSocket = false;
    plugins = with pkgs.tmuxPlugins;
      [
        vim-tmux-navigator
        yank
        plumb
        {
          plugin = resurrect;
          extraConfig = ''
            # Set before continuum starts its background restore.
            set -g @resurrect-processes '"~opencode2->opencode2 --continue" "~lazygit->lazygit" "~nvim->nvim"'
          '';
        }
        {
          plugin = continuum;
          extraConfig = ''
            # Autosave uses a systemd timer because continuum stops saving when
            # the status line below is hidden for one-window sessions.
            set -g @continuum-save-interval '0'
            set -g @continuum-restore 'on'
          '';
        }
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

        set-option -g @tmux-autoreload-configs '${config.home.homeDirectory}/.config/tmux/tmux.conf'

        # Only enable status when there is more than one window
        # from https://schauderbasis.de/posts/hide_tmux_status_bar_if_its_not_needed/
        set -g status off
        set-hook -g after-new-window      'if "[ #{session_windows} -gt 1 ]" "set status on"'
        set-hook -g after-kill-pane       'if "[ #{session_windows} -lt 2 ]" "set status off"'
        set-hook -g pane-exited           'if "[ #{session_windows} -lt 2 ]" "set status off"'
        set-hook -g window-layout-changed 'if "[ #{session_windows} -lt 2 ]" "set status off"'

        set -g default-terminal tmux-256color

        # Allow passthrough of escape sequences (needed for kitty image protocol in ranger)
        set -g allow-passthrough on

        # Pass focus events through to applications (e.g. neovim autoread)
        set -g focus-events on

        # Fixes escape being slow in vim (when in tmux)
        set -sg escape-time 0

        bind u send-keys C-l \; run-shell "sleep .5s" \; clear-history
      '';
  };

  systemd.user.services.save-tmux = {
    Unit.Description = "Save tmux sessions";
    Service = {
      Type = "oneshot";
      ExecStart = "${saveTmux}/bin/save-tmux";
    };
  };

  systemd.user.timers.save-tmux = {
    Unit.Description = "Save tmux sessions every 15 minutes";
    Timer = {
      OnStartupSec = "15min";
      OnUnitActiveSec = "15min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
