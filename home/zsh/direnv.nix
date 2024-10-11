{ ... }:
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    #may cause gc issues
    stdlib =
    ''
    tmux rename-session "#{b:pane_current_path}"
    '';
  };
  home.sessionVariables.DIRENV_LOG_FORMAT = "";
}
