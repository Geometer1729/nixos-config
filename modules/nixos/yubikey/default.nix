{ config, ... }:
{
  imports = [ ./system.nix ../password ];

  home-manager.users.${config.mainUser}.imports = [ ./home.nix ];
}
