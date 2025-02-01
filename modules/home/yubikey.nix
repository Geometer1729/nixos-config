{ pkgs, ... }:
{
  home.packages = with pkgs;
    [
      yubioath-flutter
      yubikey-manager
      yubikey-manager-qt
      pam_u2f
    ];
}
