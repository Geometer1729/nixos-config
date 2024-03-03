{lib,config,...}:
{
  home.persistence."/persist/${config.home.username}" =
    if config.home.username == "root"
    then
      { directories = [
          ".ssh"
          ".local/state/nvim"
          ".local/share/direnv"
        ];
        files = [ ".zsh_history" ];
        allowOther = false;
      }
    else
  {
    directories = [
      ".config/BraveSoftware/Brave-Browser"
      ".config/Signal"
      ".config/discord"
      ".gnupg"
      ".hoogle"
      ".local/share/PrismLauncher"
      ".local/share/Steam"
      ".local/share/direnv"
      ".local/share/task"
      ".local/state/nvim"
      ".mozilla/firefox/default"
      ".ssh"
      ".tldrc"
      "Code"
      "Documents"
      "Pictures"
      "conf"
      "memes"
      "password-store"
    ];
    files = [
      ".zsh_history"
      ".config/lazygit/state.yml"
      ];
    allowOther = true;
  };

  # It's fairly commony for a new
  # .zsh_history to apear at the wrong
  # time and break the activation
  # so just delete it when that happens
  home.activation.shell-hist-fix =
    lib.hm.dag.entryBefore
    [ "checkLinkTargets" ]
    ''
    if [ -e .zsh_history ]
    then
      rm .zsh_history
    fi
    '';
}
