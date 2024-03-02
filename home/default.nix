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
      ./tasks.nix
      ./tmux.nix
      ./xmobar
      ./xmonad
      ./zathura.nix
      ./zsh

      inputs.impermanence.nixosModules.home-manager.impermanence
      inputs.nur.nixosModules.nur
      inputs.persist-retro.nixosModules.home-manager.persist-retro
    ];
}
