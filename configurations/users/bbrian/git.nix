{
  programs.git = {
    settings.user = {
      email = "16kuhnb@gmail.com";
      name = "Geometer1729";
    };
    signing = {
      signByDefault = true;
      key = "0xA1314A37485AD93E"; # YubiKey signing key
      # On a new machine with YubiKey plugged in, run:
      #   gpg --recv-keys A1314A37485AD93E
      #   gpg-connect-agent "learn --force" /bye
    };
  };
}
