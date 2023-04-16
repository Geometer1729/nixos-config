{ pkgs, ... }:
{
  home =
    { packages =
        with pkgs;
        [
          # status tools
          htop
          gotop
          radeontop
          neofetch

          # apps
          discord
          firefox
          spotify
          signal-desktop

          # system
          home-manager
          openssh
          dmenu
          killall
          xclip
          du-dust

          # dev tools
          ripgrep
          wget
          direnv
          nix-direnv
          nil # nix lsp
          rnix-lsp
          (haskell.packages.ghc943.ghcWithPackages
            (pkgs : with pkgs;
              [ flow
                mtl
                containers
                text
                time
                generics-sop
              ]
            )
          )

          # shell
          starship
          zplug
          tldr

          # work
          slack
          cachix
          nodePackages.purescript-language-server

          # games
          prismlauncher


          # pass
          pass
          gnupg
          pinentry

          # mouse thing
          piper
          libratbag

          #fonts
          font-awesome
          fira-mono
          noto-fonts-emoji

          #misc
          pulsemixer
          spectacle #screenshots
          #picom #compositer
          feh #sets background
          playerctl # play pause controls
          zathura # pdf reader

          # TODO move these somewhere
          #scripts
          (writeShellScriptBin "playPause" ''
            if playerctl status -a  | grep Playing
            then
              echo something playing pausing everything
              playerctl pause -a
            elif [[ `playerctl -l | wc -l` -ge 2 ]]
            then
              echo nothing playing multiple choices prompting user
              playerctl play -p $(playerctl -l | dmenu)
            else
              echo nothing playing one thing to play playing it
              playerctl play
            fi
          '')
          (writeShellScriptBin "guiRebuild" ''
            alacritty \
              -t float \
              -e zsh \
              -c "sudo nixos-rebuild test || zsh"
          '')

        ];
    };

    services ={
      picom ={
        enable = true;
        #backend = "egl";
        #activeOpacity = 1;
        #inactiveOpacity = 0.9;
        #shadow = true;
        vSync = true;
      };
      gpg-agent = {
        enable = true;
        pinentryFlavor = "qt" ;
        # TODO it'd be cool to make a wrapper
        # that tries cursses then uses qt
      };
    };

    home.file.".ghc/ghci.conf".source = ./ghci.repl;

    programs.firefox.profiles.default.settings = {
      accessibility.typeaheadfind.enablesound=false;
      # TODO does this work?
    };
}

