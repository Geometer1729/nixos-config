{ ... }:
{
  nix = {
    settings = {
      builders-use-substitutes = true;
    };
    distributedBuilds = true;
    buildMachines = [
      { hostName = "am";
        maxJobs = 40;
        sshKey = "/home/bbrian/.ssh/id_ed25519";
        sshUser = "bbrian";
        system = "x86_64-linux";
      }
    ];
  };
}
