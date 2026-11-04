# Hex local voice dictation (https://anoma.ly/hex). Hyprland binds its push-to-talk key.
{ flake, config, ... }:
{
  home-manager.users.${config.mainUser} = { config, pkgs, ... }: {
    imports = [ flake.inputs.hex.homeManagerModules.hex ];
    programs.hex = {
      enable = true;
      autostart = true;
    };

    scripts.hex = {
      directory = ./.;
      extras = [ config.programs.hex.package config.programs.taskwarrior.package ]
        ++ (with pkgs; [ hyprland socat tmux wl-clipboard wtype ]);
    };
  };

  environment.persistence."/persist/system".users.${config.mainUser}.directories = [
    # Settings, History, logs, and the downloaded speech models.
    ".local/share/hex"
  ];
}
