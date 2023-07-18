{ config, pkgs, userName, hostName, ... }:
let
  keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIq6wxRwdpUdae2guAcJk/OqO8pI5jq4Q/bu96XVYwR4 bbrian@am" ];
in
{
  nix = {
    settings = {
      max-jobs = 0;
      builders-use-substitutes = true;
      # substituters = [ "10.0.0.249:5000" ];
    };
    distributedBuilds = true;
    buildMachines =
      [ { hostName = "am";
        #"10.0.0.248";
          sshUser = "bbrian";
          system = "x86_64-linux";
          sshKey = "/home/${userName}/.ssh/id_ed25519";
          maxJobs = 40;
        }
      ];
  };
  networking.wireless = {
      enable = true;
        # Enables wireless support via wpa_supplicant.
      environmentFile = "/home/${userName}/secrets/wifi";
        # contains wifi password
      networks.epicGamerWifi.psk="@HOME_WIFI@";
    };
  users.users.${userName}.openssh.authorizedKeys.keys = keys;
}
