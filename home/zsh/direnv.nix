{...}:
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    #may cause gc issues
  };
  home.sessionVariables.DIRENV_LOG_FORMAT="";
}
