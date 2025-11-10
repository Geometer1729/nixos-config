{ pkgs, lib, config, ... }:
{
  # Enable smartcard daemon for YubiKey GPG support
  services = {
    pcscd.enable = true;
    udev.packages = [ pkgs.yubikey-personalization ];
  };

  # Enable U2F for PAM authentication
  security.pam = {
    u2f = {
      enable = true;
      settings = {
        cue = true;
        authFile = "/home/${config.mainUser}/.config/Yubico/u2f_keys";
      };
    };
  };

  # GPG support for YubiKey
  programs.gnupg.agent = {
    enable = true;
  };

  # Add udev rules for YubiKey
  services.udev.extraRules = ''
    # YubiKey permissions
    SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0407", MODE="0660", GROUP="users"

    # Kill scdaemon when YubiKey is removed to prevent exclusive lock issues
    ACTION=="remove", ENV{ID_VENDOR_ID}=="1050", ENV{ID_MODEL_ID}=="0407", RUN+="${pkgs.gnupg}/bin/gpgconf --kill scdaemon"
  '';
}
