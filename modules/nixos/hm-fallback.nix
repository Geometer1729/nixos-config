{ config, lib, pkgs, ... }:
{
  specialisation.rescue.configuration = {
    system.nixos.tags = [ "rescue" ];

    # Disable home-manager entirely
    systemd.services."home-manager-${config.mainUser}".enable = lib.mkForce false;
    systemd.services.home-manager-root.enable = lib.mkForce false;

    # Force root to bash — no zsh histfile issues, no HM dependency
    users.users.root.shell = lib.mkForce pkgs.bash;

    # Essentials that normally come from HM
    environment.systemPackages = with pkgs; [
      vim
      tmux
      git
      htop
    ];

    # Root TTY auto-login, no display manager
    services.displayManager.autoLogin.enable = lib.mkForce false;
    services.displayManager.sddm.enable = lib.mkForce false;
    services.getty.autologinUser = lib.mkForce "root";
  };
}
