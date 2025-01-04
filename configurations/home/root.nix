{flake,...}:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  home.stateVersion = "22.05";
  home.username = "root";
  home.homeDirectory = "/root";

  imports = with self.homeModules; [
    inputs.nixvim.homeManagerModules.nixvim
    git
    nvim
    tmux
    zsh
    ssh
  ];

}
