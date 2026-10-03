# Per-user Hyprland session.
{ config, pkgs, ... }:
{
  imports = [
    ../../../home/cliphist
    ../../../home/dictation
    ./hyprland.nix
    ./waybar.nix
    ./hyprpaper.nix
    ./hypridle.nix
    ./hyprlock.nix
    ./rofi.nix
  ];

  scripts.hyprland = {
    directory = ./.;
    extras = with pkgs; [ hyprland tmux ];
    overrides.onScratchPad.extras = [ config.scripts.hyprland.packages.scratchPad ];
    overrides.notification-center.extras = with pkgs; [ mako wl-clipboard ];
    overrides.key-help = {
      extras = [ config.programs.rofi.package ];
      runtimeEnv.KEY_HELP_PROGRAMS = "${pkgs.writeText "key-help.json" (builtins.toJSON config.keyHelp)}";
    };
  };

  keyHelp.hyprland = {
    label = "Hyprland";
    order = 0;
    binds = [{
      key = "Alt+Shift+/";
      description = "Search all Hyprland binds";
      command = "rofi -show keybinds";
    }];
  };
}
