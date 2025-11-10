{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # Password management
    pass
    gnupg
    rofi-pass
  ];

  # GPG agent configuration for YubiKey support
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-qt;
    # TODO it'd be cool to make a wrapper
    # that tries curses then uses qt

    # Cache settings for YubiKey
    defaultCacheTtl = 600;
    maxCacheTtl = 7200;
  };

  # GPG configuration for YubiKey
  programs.gpg = {
    enable = true;
    settings = {
      # Use agent for key operations
      use-agent = true;

      # Prefer stronger algorithms
      personal-cipher-preferences = "AES256 AES192 AES";
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
      default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
      cert-digest-algo = "SHA512";
      s2k-digest-algo = "SHA512";
      s2k-cipher-algo = "AES256";

      # Show long key IDs
      keyid-format = "0xlong";
      with-fingerprint = true;
    };
  };

  # Password store directory
  home.sessionVariables = {
    PASSWORD_STORE_DIR = "${config.home.homeDirectory}/password-store";
  };
}
