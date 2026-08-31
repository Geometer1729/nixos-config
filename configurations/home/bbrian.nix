{ flake, lib, machine, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  home.stateVersion = "25.05";
  home.username = "bbrian";
  home.homeDirectory = "/home/bbrian";

  imports = with self.homeModules;
    [ inputs.nixvim.homeModules.nixvim ]
    ++ lib.optionals machine.hasGui [ ghostty ]
    ++ [ ranger ]
    ++ lib.optionals machine.hasGui [ brave firefox hyprland ]
    ++ [ system ]
    ++ lib.optionals machine.hasGui [ systemd-failure-notifications desktop ]
    ++ [ development ]
    ++ lib.optionals machine.hasGui [ media communication ]
    ++ [ password ]
    ++ lib.optionals machine.hasGui [ gaming ]
    ++ [
      git
      nvim
      scripts
      ssh
      syncthing
      tasks
      tmux
    ]
    ++ lib.optionals machine.hasGui [ work ]
    ++ [
      yubikey
      zsh
      claude
      opencode
    ]
    ++ lib.optionals machine.hasGui [ webapps ];

  # Disable speech-dispatcher - comes as a dependency but not needed
  systemd.user.services.speech-dispatcher = lib.mkForce { };
  systemd.user.sockets.speech-dispatcher = lib.mkForce { };

}
