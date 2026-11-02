# Hex local voice dictation (https://anoma.ly/hex). Hyprland binds its push-to-talk key.
{ flake, config, ... }:
{
  home-manager.users.${config.mainUser} = {
    imports = [ flake.inputs.hex.homeManagerModules.hex ];
    programs.hex = {
      enable = true;
      autostart = true;
    };
  };

  environment.persistence."/persist/system".users.${config.mainUser}.directories = [
    # Settings, History, logs, and the downloaded speech models.
    ".local/share/hex"
  ];
}
