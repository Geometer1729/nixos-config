{
  programs.git = {
    settings.user = {
      email = "16kuhnb@gmail.com";
      name = "Geometer1729";
    };
    signing = {
      signByDefault = true;
      key = "0xA1314A37485AD93E"; # Primary YubiKey; the yubikey module signs with whichever card is plugged in
      # On a new machine, with a YubiKey plugged in, run:
      #   gpg-connect-agent "learn --force" /bye
    };
  };
}
