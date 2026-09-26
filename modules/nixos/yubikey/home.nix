{ config, lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    # YubiKey management tools
    yubikey-manager # CLI tool for YubiKey management
    yubikey-personalization # Tool for personalizing YubiKey

    # Authentication
    pam_u2f # U2F PAM module

    # GPG tools for YubiKey
    gnupg # Already in password.nix but listing for clarity
    paperkey # Backup GPG keys to paper
    pcsc-tools # Tools for smartcard communication (useful for debugging)
  ];

  # Public halves of the primary and backup YubiKeys; pass encrypts to both.
  programs.gpg.publicKeys = [
    { source = ./primary.asc; trust = "ultimate"; }
    { source = ./backup.asc; trust = "ultimate"; }
  ];

  # Only used as git's signer, so keep it off PATH.
  scripts.yubikey-git = {
    directory = ./git;
    enable = false;
    extras = [ pkgs.gnupg ];
  };
  programs.git.settings.gpg.program =
    lib.getExe config.scripts.yubikey-git.packages.gpg-yubikey-sign;

  # Ensure XDG directories exist for YubiKey config
  xdg.configFile."Yubico/.keep".text = "";
}
