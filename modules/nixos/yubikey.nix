{ pkgs, lib, config, ... }:
{
  # Enable smartcard daemon for YubiKey GPG support
  services = {
    pcscd.enable = true;
    udev.packages = [ pkgs.yubikey-personalization ];
    yubikey-agent.enable = true;
  };

  # Enable U2F for PAM authentication
  security.pam = {
    sshAgentAuth.enable = true;
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
    enableSSHSupport = true;
  };

  # Add udev rules for YubiKey
  services.udev.extraRules = ''
    # YubiKey
    SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0407", MODE="0660", GROUP="users"
  '';
}
