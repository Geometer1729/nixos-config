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
      ./persist.nix

      inputs.impermanence.nixosModules.home-manager.impermanence
      inputs.nur.nixosModules.nur
    ];
}
