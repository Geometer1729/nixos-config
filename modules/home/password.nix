{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # Password management
    pass
    gnupg
    pinentry
  ];

  # GPG agent configuration
  services.gpg-agent = {
    enable = true;
    # TODO why doesn't this work?
    #pinentryPackage = pkgs.pinentry-rofi;
    pinentryPackage = pkgs.pinentry-qt;
    # TODO it'd be cool to make a wrapper
    # that tries cursses then uses qt
  };

  # Password store directory
  home.sessionVariables = {
    PASSWORD_STORE_DIR = "${config.home.homeDirectory}/password-store";
  };
}
