{inputs,...}:
{
  imports =
    [ ./alacritty.nix
      ./firefox.nix
      ./git.nix
      ./impermanence.nix
      ./main.nix
      ./nvim
      ./scripts
      ./ssh.nix
      ./sway.nix
      ./tasks
      ./tmux.nix
      ./xmobar
      ./xmonad
      ./zathura.nix
      ./zsh
      ./mime.nix

      inputs.impermanence.nixosModules.home-manager.impermanence
      inputs.nur.nixosModules.nur
      inputs.persist-retro.nixosModules.home-manager.persist-retro
    ];
}
