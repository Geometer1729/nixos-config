{lib,config,...}:
{
  home.persistence."/persist/${config.home.username}" = {
    directories = [
      ".config/BraveSoftware/Brave-Browser"
      ".config/discord"
      ".config/Signal"
      ".gnupg"
      ".hoogle"
      ".local/share/PrismLauncher"
      ".local/share/Steam"
      ".local/share/direnv"
      ".local/share/task"
      ".mozilla/firefox/default/"
      ".ssh"
      "Code"
      "Documents"
      "Pictures"
      "conf"
      "memes"
      "password-store"
      ".local/state/nvim/undo"
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
