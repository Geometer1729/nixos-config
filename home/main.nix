{ pkgs, userName, ... }:
{
  home =
    {
      packages =
        with pkgs;
        [
          # status tools
          htop
          radeontop
          neofetch

          # video
          ffmpeg
          youtube-dl
          vlc

          # apps
          discord
          element-desktop # matrix client
          brave
          spotify
          signal-desktop
          zathura # pdf

          # system
          home-manager
          openssh
          killall
          xclip
          du-dust # disk usage tool
          nix-du # makes a graph of the nix store dependencies
          graphviz # renders graphs (like the nix-du ones)
          unzip


          # dev tools
          tmate
          tmux
          ripgrep
          wget
          deploy-rs
          nh # nix helper
          nix-output-monitor
          nixpkgs-fmt
          xorg.xev # x event viewer (sometimes needed for xmonad dev)

          expect # provides unbuffer
          nil # nix lsp
          #rnix-lsp unmaintained? TODO replace this I guess
          (haskell.packages.ghc94.ghcWithPackages
            (pkgs: with pkgs;
            [
              flow
              mtl
              containers
              text
              time
              generics-sop
            ]
            )
          )
          haskellPackages.hoogle

          # shell
          starship #prompt
          zplug
          tldr

          # games
          prismlauncher

          # pass
          pass
          gnupg
          pinentry
          yubikey-manager

          # mouse thing
          piper
          libratbag

          #fonts
          font-awesome
          fira-mono
          noto-fonts-emoji

          #misc
          pulsemixer
          feh #sets background
          sxiv # simple x image viewer
          playerctl # play pause controls
          imagemagick
          calcurse # calandar
          xmonadctl # xmonad server mode control
          ranger # tui file browser
          xdotool
          arp-scan # network scaner
          cloc # count lines of code
          okteta # hex editor
          #zoom-us # video calls
        ];
    };

  services = {
    picom = {
      enable = true;
      vSync = true;
    };
    gpg-agent = {
      enable = true;
      # TODO why doesn't this work?
      #pinentryPackage = pkgs.pinentry-rofi;
      pinentryPackage = pkgs.pinentry-qt;
      # TODO it'd be cool to make a wrapper
      # that tries cursses then uses qt
    };
    # screenshots
    flameshot =
      {
        enable = true;
        settings =
          {
            General =
              {
                savePath = "/home/bbrian/Downloads";
                showHelp = false;
                uiColor = "#0ce3ff";
                contrastOpacity = 188;
                buttons = # magic string from gui config editor
                  ''
                    @Variant(\0\0\0\x7f\0\0\0\vQList<int>\0\0\0\0\v\0\0\0\0\0\0\0\x1\0\0\0\x2\0\0\0\x3\0\0\0\x4\0\0\0\x5\0\0\0\x6\0\0\0\x12\0\0\0\b\0\0\0\n\0\0\0\v)
                  '';
              };
          };
      };
  };

  home.file.".ghc/ghci.conf".source = ./ghci.repl;

  home.sessionVariables = {
    FLAKE = "/home/${userName}/conf";
    PASSWORD_STORE_DIR = "/home/${userName}/password-store";
  };

  programs.rofi = {
    enable = true;
    pass.enable = true;
    terminal = "alacritty"; # not working
  };

  programs.btop.enable = true;
  # TODO hide repeated disks in btop

}

