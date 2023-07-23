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
          sshUser = "bbrian";
          system = "x86_64-linux";
          sshKey = "/home/${userName}/.ssh/id_ed25519";
          maxJobs = 40;
        }
      ];
  };
}
