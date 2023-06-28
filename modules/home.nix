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

          # video
          ffmpeg
          youtube-dl
          vlc

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
          tmate
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
          #picom #compositer
          feh #sets background
          playerctl # play pause controls
          zathura # pdf reader
          imagemagick
          calcurse
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
      # screenshots
      flameshot =
        { enable = true;
          settings =
            { General =
                { savePath = "/home/bbrian/Downloads";
                  showHelp = false;
                  uiColor = "#0ce3ff";
                  contrastOpacity = 188;
                  buttons= # magic string from gui config editor
                    ''
                    @Variant(\0\0\0\x7f\0\0\0\vQList<int>\0\0\0\0\v\0\0\0\0\0\0\0\x1\0\0\0\x2\0\0\0\x3\0\0\0\x4\0\0\0\x5\0\0\0\x6\0\0\0\x12\0\0\0\b\0\0\0\n\0\0\0\v)
                    '';
                };
            };
        };
    };

    home.file.".ghc/ghci.conf".source = ./ghci.repl;

    programs.firefox.profiles.default.settings = {
      accessibility.typeaheadfind.enablesound=false;
      # TODO does this work?
    };


  }

