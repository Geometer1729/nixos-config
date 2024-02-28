{userName,config,...}:
{
  home.persistence."/persist/${config.home.username}" = {
    directories = [
      ".config/BraveSoftware/Brave-Browser"
      ".config/discord"
      ".gnupg"
      ".hoogle"
      ".local/share/PrismLauncher"
      ".local/share/Steam"
      ".local/share/direnv"
      ".mozilla/firefox/default/"
      ".ssh"
      "Code"
      "Documents"
      "Pictures"
      "conf"
      "memes"
      "password-store"
    ];
    files = [
      ".zsh_history"
      ];
    allowOther = true;
  };
  home.sessionVariables.NIXOS_CONFIG="/home/${userName}/conf/flake.nix";
}
