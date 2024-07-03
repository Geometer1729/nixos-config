{ inputs, pkgs, userName, hostName, secrets, config, system, ... }:

{

  networking = {
    inherit hostName;
    hosts =
      {
        "${secrets.jsh.ip}" = [ "jsh.gov" ];
        # "72.231.188.127" = [ "foundry.anthonyrinaldo.com" ];
      };
  };

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.utf8";

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays =
    [
      (final: prev: {
        gotop = prev.gotop.overrideAttrs
          (old: { patches = [ ./gotop.patch ]; });
        # fix by gardockt on github
      })
      (final: prev: {
        flameshot = prev.flameshot.overrideAttrs
          (old:
            let
              version = "11.0.0";
              # seems to fix clipboard issue
              # issue is not consistant so it's hard to bisect
            in
            {
              inherit version;
              src = final.fetchFromGitHub {
                owner = "flameshot-org";
                repo = "flameshot";
                rev = "v${version}";
                sha256 = "sha256-SlnEXW3Uhdgl0icwYyYsKQOcYkAtHpAvL6LMXBF2gWM=";
              };
            }
          );
      })
      (final: prev: {
        # Taskopen was rewritten in nim
        # so it's easier to start from scratch than overrideAttrs
        # Once I know everything works I should update it in nixpkgs too
        taskopen =
          let
            version = "2.0.1";
            src = pkgs.fetchFromGitHub {
              owner = "ValiValpas";
              repo = "taskopen";
              rev = "v${version}";
              sha256 = "sha256-Gy0QS+FCpg5NGSctVspw+tNiBnBufw28PLqKxnaEV7I=";
            };
          in
          pkgs.buildNimPackage
            {
              name = "task-open";
              src = "${src}/src";
              nimbleFile = "${src}/taskopen.nimble";
            };
      })
      (final: prev: {
        discord =
          let
            master = import inputs.nixpkgs-master
              { inherit system; config.allowUnfree = true; }
            ;
          in
          master.discord;
      })
    ];

  #steam needs this
  hardware =
    {
      pulseaudio.support32Bit = true;
      graphics = {
        enable = true;
        #driSupport32Bit = true;
        extraPackages = [ pkgs.amdvlk ];
        extraPackages32 = with pkgs.pkgsi686Linux; [ libva amdvlk ];
      };
    };
  security.pam.loginLimits = [
    { domain = "*"; item = "nofile"; type = "-"; value = 16777216; }
  ];
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [

    # Add any missing dynamic libraries for unpackaged programs

    # here, NOT in environment.systemPackages
    # common requirement for several games
    stdenv.cc.cc.lib

    # from https://github.com/NixOS/nixpkgs/blob/nixos-23.05/pkgs/games/steam/fhsenv.nix#L72-L79
    xorg.libXcomposite
    xorg.libXtst
    xorg.libXrandr
    xorg.libXext
    xorg.libX11
    xorg.libXfixes
    libGL
    libva

    # from https://github.com/NixOS/nixpkgs/blob/nixos-23.05/pkgs/games/steam/fhsenv.nix#L124-L136
    fontconfig
    freetype
    xorg.libXt
    xorg.libXmu
    libogg
    libvorbis
    SDL
    SDL2_image
    glew110
    libdrm
    libidn
    tbb

  ];

  #downloads as a tmpfs
  fileSystems."/home/${userName}/Downloads" =
    {
      device = "none";
      fsType = "tmpfs";
    };

  nix = {
    # TODO extra platforms for am
    # build machines for raptor
    # ssh store
    settings = {
      substituters = [ "https://cache.nixos.org" ];
      trusted-substituters = [ "https://cache.nixos.org" ];
      trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
      warn-dirty = false;
      #accept-flake-config = true;
      log-lines = 25;
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" "ca-derivations" "recursive-nix" ];
      trusted-users = [ "root" userName ];
    };
    gc = {
      automatic = true;
      options = "--delete-older-than 21d";
      # cleans up old home-manager genrations
      dates = "weekly";
    };
  };

  # Sound
  #sound.enable = true;
  #hardware.pulseaudio.enable = false;

  security.rtkit.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # services
  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        X11Forwarding=true;
        X11USeLocalhost = true;
      };
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    ratbagd.enable = true;
    xserver = {
      # system just feels a bit more responsive
      autoRepeatInterval = 20;
      autoRepeatDelay = 400;
    };
    # TODO try adding picom blur and reducing alacrity opacity
  };


  users.users.root = {
    inherit (secrets) hashedPassword;
    shell = pkgs.zsh;
  };
  users.users.${userName} = {
    inherit (secrets) hashedPassword;
    isNormalUser = true;
    description = userName;
    shell = pkgs.zsh; # TODO can home-manager do this?
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      picom # afaict this is needed for picom to work
      steam
      steam-run
      libgdiplus
      glxinfo
    ];
  };

  programs.zsh.enable = true;
  # required for nix tab completion

}
