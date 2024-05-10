{ userName, machines, ... }:
{
  nix = {
    settings = {
      max-jobs = 4;
      builders-use-substitutes = true;
    };
    distributedBuilds = true;
    buildMachines =
      builtins.map
        ({ hostName, system, ... }:
          {
            inherit hostName system;
            sshUser = userName;
            sshKey = "/home/${userName}/.ssh/id_ed25519";
            maxJobs = 40;
          })
        (builtins.filter ({ builder, ... }: builder)
          (builtins.attrValues
            (builtins.mapAttrs (name: rest: rest // { hostName = name; })
              machines
            )));
  };
}
