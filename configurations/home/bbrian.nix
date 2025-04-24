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

    alacritty
    firefox
    git
    main
    mime
    nvim
    scripts
    ssh
    sway
    tasks
    tmux
    work
    xmobar
    xmonad
    #yubikey
    zsh
  ];

}
