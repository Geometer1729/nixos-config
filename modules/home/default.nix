{ inputs, nixosConfig, ... }:
{
  imports =
    [
      #./alacritty.nix
      #./firefox.nix
      #./git.nix
      #./main.nix
      #./mime.nix
      #./nvim
      #./scripts
      #./ssh.nix
      #./sway.nix
      #./tasks
      #./tmux.nix
      #./xmobar
      #./xmonad
      #./zsh
      #./work.nix

      inputs.nur.modules.homeManager.default
      inputs.nixvim.homeManagerModules.nixvim
    ];
}
