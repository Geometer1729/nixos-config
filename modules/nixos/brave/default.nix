{ config, ... }:
{
  imports = [ ./system.nix ];

  home-manager.users.${config.mainUser}.imports = [ ./home.nix ];

  environment.persistence."/persist/system".users.${config.mainUser}.directories = [
    ".config/BraveSoftware/Brave-Origin"
  ];
}
