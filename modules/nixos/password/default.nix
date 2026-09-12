{ config, ... }:
{
  home-manager.users.${config.mainUser}.imports = [ ./home.nix ];

  environment.persistence."/persist/system".users.${config.mainUser}.directories = [
    ".gnupg"
    "password-store"
  ];
}
