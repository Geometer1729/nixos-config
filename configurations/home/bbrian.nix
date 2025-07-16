{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  home.stateVersion = "22.05";
  home.username = "bbrian";
  home.homeDirectory = "/home/bbrian";

  imports = with self.homeModules; [
    inputs.nur.modules.homeManager.default
    inputs.nixvim.homeManagerModules.nixvim

    # GUI applications
    alacritty
    firefox
    sway
    xmobar
    xmonad

    # System configuration
    system
    desktop
    development
    media
    communication
    password
    gaming

    # Core functionality
    git
    mime
    nvim
    scripts
    ssh
    tasks
    tmux
    work
    #yubikey
    zsh
    claude
  ];

}
