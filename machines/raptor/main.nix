{ userName, ... }:
{
  nix = {
    settings = {
      max-jobs = 0;
      builders-use-substitutes = true;
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
}
