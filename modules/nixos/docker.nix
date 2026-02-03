{ config, ... }:
{
  virtualisation.docker.enable = true;

  # Add main user to docker group
  users.users.${config.mainUser}.extraGroups = [ "docker" ];
}
