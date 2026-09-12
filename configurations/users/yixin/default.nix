{ config, lib, pkgs, ... }:
{
  users.users.yixin = {
    hashedPasswordFile = config.sops.secrets.yixinHashedPassword.path;
    isNormalUser = true;
    description = "Yixin";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = import ../../../ssh-authorized-keys.nix;
  };

  home-manager.users.yixin.imports = [ ./home.nix ];
  nix.settings.trusted-users = lib.mkAfter [ "yixin" ];
}
