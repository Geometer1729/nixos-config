{ config, ... }:
let
  owned = { owner = config.mainUser; };
in
{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";
    age = {
      keyFile = "/persist/system/home/${config.mainUser}/.config/sops/age/keys.txt";
      sshKeyPaths = [ "/persist/system/home/${config.mainUser}/.ssh/id_ed25519" ];
      generateKey = true;
    };

    secrets.wifi = owned;
    secrets.hashedPassword = owned // { neededForUsers = true; };
    secrets.hosts = owned;
  };
  # secret hosts
  environment.etc.hosts.mode = "0644";
  system.activationScripts.hosts = {
    deps = [ "setupSecrets" "etc" ];
    text = ''
      cat /run/secrets/hosts >> /etc/hosts
    '';
  };
}
