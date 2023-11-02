{ machines,hostName,userName,... } :
{
    programs.ssh = {
      enable = true;
      matchBlocks = {
        tub = {
          hostname = "jsh.gov";
          user = userName;
          identityFile = "~/.ssh/id_ed25519";
        };
        vesta = {
          hostname = "192.168.1.41";
          user = "vesta";
          identityFile = "~/.ssh/id_ed25519";
        };
      }
      //
      ( builtins.mapAttrs
        (name: machine:
         { hostname = if name == hostName then "localhost" else machine.ip;
           user = userName;
           identityFile = "/home/${userName}/.ssh/id_ed25519";
           # Using ~ makes the path wrong for root
         }
        ) machines
      )
      ;
    };
}
