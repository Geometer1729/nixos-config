{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # YubiKey management tools
    yubioath-flutter # TOTP/HOTP authenticator (also serves as GUI for YubiKey)
    yubikey-manager # CLI tool for YubiKey management
    yubikey-personalization # Tool for personalizing YubiKey

    # Authentication
    pam_u2f # U2F PAM module

    # GPG tools for YubiKey
    gnupg # Already in password.nix but listing for clarity
    paperkey # Backup GPG keys to paper
    pcsctools # Tools for smartcard communication (useful for debugging)
  ];

  # Ensure XDG directories exist for YubiKey config
  xdg.configFile."Yubico/.keep".text = "";
}
