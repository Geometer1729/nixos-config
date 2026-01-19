{ flake, lib, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  home.stateVersion = "25.05";
  home.username = "bbrian";
  home.homeDirectory = "/home/bbrian";

  imports = with self.homeModules; [
    inputs.nixvim.homeModules.nixvim

    # GUI applications
    alacritty
    firefox
    hyprland

    # System configuration
    system
    systemd-failure-notifications
    desktop
    development
    media
    communication
    password
    gaming

    # Core functionality
    git
    nvim
    scripts
    ssh
    syncthing
    tasks
    tmux
    work
    yubikey
    zsh
    claude
    webapps
  ];

  # Disable speech-dispatcher - comes as a dependency but not needed
  systemd.user.services.speech-dispatcher = lib.mkForce { };
  systemd.user.sockets.speech-dispatcher = lib.mkForce { };

}
