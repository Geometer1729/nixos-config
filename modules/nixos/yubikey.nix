{ pkgs, lib, config, ... }:
{
  services = {
    pcscd.enable = true;
    udev.packages = [ pkgs.yubikey-personalization ];
    yubikey-agent.enable = true;
  };

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
}
