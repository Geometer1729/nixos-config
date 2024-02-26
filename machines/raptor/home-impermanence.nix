{userName,...}:
{
  home.persistence."/persist/${userName}" = {
    directories = [
      "Documents"
      "Code"
      "Pictures"
      ".gnupg"
      ".ssh"
      ".local/share/direnv"
      ".local/share/Steam"
      ".local/share/PrismLauncher"
      "password-store"
      "memes"
      ".zsh_history"
      ".hoogle"
      ".mozila"
      ".config/discord"
      ".config/BraveSoftware/Brave-Browser"
      "conf"
    ];
    allowOther = true;
  };
  home.sessionVariables.NIXOS_CONFIG="/home/bbrian/conf/flake.nix";
}
