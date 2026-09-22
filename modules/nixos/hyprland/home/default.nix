# Per-user Hyprland session.
{ config, pkgs, ... }:
{
  imports = [
    ../../../home/cliphist
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
  };
}
