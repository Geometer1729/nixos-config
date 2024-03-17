{opts,inputs,...}:
{
  imports =
    [ inputs.disko.nixosModules.default
      inputs.impermanence.nixosModules.impermanence
      #inputs.persist-retro.nixosModules.persist-retro
      ./boot.nix
      ./main.nix
      ./xmonad.nix
      ./ssh.nix
      ./disko.nix
      ./impermanence.nix
    ]
    ++ (if opts.wifi.enable then [ ./wifi.nix ] else [])
    ++ (if opts.builder then [ ./builder.nix ] else [ ./useBuilders.nix ])
    ;
}
