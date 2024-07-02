{ inputs, nixosConfig, ... }:
{
  imports =
    [
      ./alacritty.nix
      ./firefox.nix
      ./git.nix
      ./impermanence.nix
      ./main.nix
      ./mime.nix
      ./nvim
      ./scripts
      ./ssh.nix
      ./sway.nix
      ./tasks
      ./tmux.nix
      ./xmobar
      ./xmonad
      ./zsh
      ./work.nix

      inputs.impermanence.nixosModules.home-manager.impermanence
      inputs.nur.nixosModules.nur
      inputs.persist-retro.nixosModules.home-manager.persist-retro
      inputs.nixvim.homeManagerModules.nixvim
    ];
}
