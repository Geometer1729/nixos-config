{inputs,...}:
{
  imports =
    [ ./alacritty.nix
      ./git.nix
      ./main.nix
      ./nvim
      ./scripts
      ./ssh.nix
      ./sway.nix
      ./tmux.nix
      ./xmobar
      ./xmonad
      ./zathura.nix
      ./zsh
      ./firefox.nix
      ./impermanence.nix
      inputs.impermanence.nixosModules.home-manager.impermanence
      inputs.nur.nixosModules.nur
    ];
}
