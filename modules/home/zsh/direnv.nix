{ ... }:
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true; # Mostly for claude
    nix-direnv.enable = true;
    #may cause gc issues
    stdlib =
      ''
        # Tmux session management
        if [ -n "$TMUX" ] && [ -z "$DIRENV_NO_TMUX_RENAME" ]; then
          session_name=$(basename "$PWD")
          current_session=$(tmux display-message -p '#S')

          if [ "$current_session" != "$session_name" ]; then
            if tmux has-session -t "$session_name" 2>/dev/null; then
              printf "Tmux session '%s' already exists. Attach to it? [y/n] " "$session_name"
              read -r answer
              if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
                tmux switch-client -t "$session_name" \
                  && tmux kill-session -t $(tmux display-message -p '#{session_name}')
              fi
            else
              tmux rename-session "$session_name"
              export DIRENV_NO_TMUX_RENAME=1
            fi
          fi
        fi

        # Claude Code account isolation
        # ~/Code/work/* uses work config, everything else uses personal
        if [[ "$PWD" == "$HOME/Code/work"* ]]; then
          export CLAUDE_CONFIG_DIR="$HOME/.claude-work"
        else
          export CLAUDE_CONFIG_DIR="$HOME/.claude-personal"
        fi
      '';
  };
  home.sessionVariables.DIRENV_LOG_FORMAT = "";
}
