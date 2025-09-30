{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  home.stateVersion = "22.05";
  home.username = "root";
  home.homeDirectory = "/root";

  imports = with self.homeModules; [
    inputs.nixvim.homeModules.nixvim
    git
    nvim
    tmux
    zsh
    ssh
  ];

}
