{config,...}:
let
  owned = { owner = config.mainUser; path = "/test-path"; };
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

    secrets.hosts = owned;
    secrets.wifi = owned;
    secrets.hashedPassword = owned // { neededForUsers = true ; };
  };
}
