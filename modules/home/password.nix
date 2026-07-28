{ config, pkgs, ... }:
let
  passPackage = pkgs.pass-wayland.override { dmenuSupport = false; };
  passmenu = pkgs.writeShellApplication {
    name = "passmenu";
    runtimeInputs = [ passPackage pkgs.rofi ];
    text = ''
      shopt -s nullglob globstar

      prefix="''${PASSWORD_STORE_DIR:-$HOME/.password-store}"
      password_files=("$prefix"/**/*.gpg)

      if (( ''${#password_files[@]} == 0 )); then
        printf 'No password entries found in %s\n' "$prefix" >&2
        exit 1
      fi

      entries=()
      for password_file in "''${password_files[@]}"; do
        entry="''${password_file#"$prefix"/}"
        entries+=("''${entry%.gpg}")
      done

      password="$(printf '%s\n' "''${entries[@]}" | rofi -dmenu -i -p Password)" || exit 0
      [[ -n "$password" ]] || exit 0

      export PINENTRY_USER_DATA=gui
      pass show --clip "$password"
    '';
  };
  smartPinentry = import ../lib/smart-pinentry.nix { inherit pkgs; };
in
{
  home.packages = with pkgs; [
    # Password management
    gnupg
    passPackage
    passmenu
  ];

  # GPG agent configuration for YubiKey support
  services.gpg-agent = {
    enable = true;
    pinentry.package = smartPinentry;

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
