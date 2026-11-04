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
    overrides.notification-center.extras = with pkgs; [ mako wl-clipboard ];
    overrides.key-help = {
      extras = [ config.programs.rofi.package ];
      runtimeEnv.KEY_HELP_PROGRAMS = "${pkgs.writeText "key-help.json" (builtins.toJSON config.keyHelp)}";
    };
  };

  # The backend only reads user config; its system config dir is in the store.
  # Without a TTY Ghostty's single-instance detection hands the window to a
  # running instance and returns at once, which the portal reads as a cancel.
  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=ranger-wrapper.sh
    default_dir=$HOME
    env=TERMCMD=ghostty --gtk-single-instance=false --title=termfilechooser -e
    open_mode=suggested
    save_mode=suggested
  '';

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
