{ config, ... }:
{
  imports = [ ./system.nix ];

  home-manager.users.${config.mainUser}.imports = [ ./home ];

  environment.persistence."/persist/system" = {
    directories = [
      {
        directory = "/var/cache/tuigreet";
        user = "greeter";
        group = "greeter";
        mode = "0755";
      }
    ];
    users.${config.mainUser}.files = [
      ".cache/rofi3.druncache"
      ".cache/rofi-2.sshcache"
      ".cache/rofi-entry-history.txt"
    ];
  };
}
