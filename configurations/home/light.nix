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
    inputs.stylix.homeModules.stylix

    # System configuration
    system
    development

    # Core functionality
    git
    nvim
    ssh
    tmux
    zsh
    claude
  ];

}
