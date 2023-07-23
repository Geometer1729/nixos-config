{opts,...}:
{
  imports =
    [ ./boot.nix
      ./main.nix
      ./xmonad.nix
      ./ssh.nix
    ]
    ++ (if opts.wifi then [ ./wifi.nix ] else [])
    ++ (if opts.builder then [ ./builder.nix ] else [ ./useBuilders.nix ])
    ;
}
