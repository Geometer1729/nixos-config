{ config, pkgs, lib, userName, ... }:
{
    programs.ssh = {
      enable = true;
      matchBlocks = {
        raptor = {
          hostname = "10.0.0.29";
          user = userName;
          identityFile = "~/.ssh/id_ed25519";
        };
        tub = {
          hostname = "jsh.gov";
          user = userName;
          identityFile = "~/.ssh/id_ed25519";
        };
      };
    };
}
