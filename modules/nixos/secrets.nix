{config,...}:
let
  owned = { owner = config.mainUser; };
in
{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";
    age = {
      keyFile = "/home/${config.mainUser}/.config/sops/age/keys.txt";
      sshKeyPaths = [ "/home/${config.mainUser}/.ssh/ed_25519" ];
      generateKey = true;
    };

    secrets.hosts = owned;
    secrets.wifi = owned;
    secrets.hashedPassword = owned // { neededForUsers = true ; };
  };
}
