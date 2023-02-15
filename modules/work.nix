{ config, pkgs, userName, hostName, ... }:
{
  # work
  services.postgresql.enable = true;
  virtualisation.docker.enable=true;
  users.users.${userName}.extraGroups = [ "docker" ];
}
