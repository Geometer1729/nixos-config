{ lib, config, ... }:
{
  home.persistence."/persist/${config.home.username}" =
    if config.home.username == "root"
    then
      {
        directories = [
          # Ideally automate sharing this key with root
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
          ".config/spotify"
          ".config/Slack"
          ".gnupg"
          ".hoogle"
          {
            directory = ".local/share/PrismLauncher";
            method = "symlink";
          }
          {
            directory = ".local/share/Steam";
            method = "symlink";
          }
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
          ".cache/nix-index/files"
        ];
        allowOther = true;
      };

  # It's fairly common for a new
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
