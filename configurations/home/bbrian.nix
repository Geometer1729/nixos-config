{ flake, lib, machine, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  home.stateVersion = "25.05";
  home.username = "bbrian";
  home.homeDirectory = "/home/bbrian";

  imports = (with self.homeModules; [
    inputs.nixvim.homeModules.nixvim

    ranger

    # System configuration
    system
    development
    password

    # Core functionality
    git
    nvim
    scripts
    ssh
    syncthing
    tasks
    tmux
    yubikey
    zsh
    claude
    opencode
  ]) ++ lib.optionals machine.hasGui (with self.homeModules; [
    ghostty
    brave
    firefox
    hyprland
    systemd-failure-notifications
    desktop
    media
    communication
    gaming
    work
    webapps
  ]);

  # Disable speech-dispatcher - comes as a dependency but not needed
  systemd.user.services.speech-dispatcher = lib.mkForce { };
  systemd.user.sockets.speech-dispatcher = lib.mkForce { };

}
