{ inputs, pkgs, system, config,... }:
let
  inherit (pkgs) lib;
in
{
  options = {
    amd = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable options that make sense for amd";
    };

    mainUser = lib.mkOption {
      type = lib.types.str;
      default = "user";
      description = "main user of the system";
    };
  };

  config = {

    networking = {
      hostFiles = let hostsPath = config.sops.secrets.hosts.path; in
        # unfortunately this takes 2 rebuilds to take effect/update
        # it's not ideal but I don't know a better way to have this work with
        # sops-nix
        lib.optional (builtins.pathExists hostsPath) hostsPath;
    };

    time.timeZone = "America/New_York";
    i18n.defaultLocale = "en_US.utf8";

    nixpkgs.config.allowUnfree = true;
    # TODO move to overlays
    nixpkgs.overlays =
      [
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
      ];

    #steam needs this
    hardware =
      {
        pulseaudio.support32Bit = true;
        graphics = {
          enable = true;
          enable32Bit = true;
        };
      } // (if config.amd then
        {
          amdgpu.amdvlk= {
            enable = true;
            support32Bit.enable = true;
          };
        } else {});

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

    nix = {
      # TODO extra platforms for am
      # build machines for raptor
      # ssh store
      # imrpoves nixlsp but breaks nix-shell -p
      #nixPath = [ "nixpkgs-=${inputs.nixpkgs}" ];
      package = pkgs.nixVersions.latest;
      settings = {
        substituters = [ "https://cache.nixos.org" ];
        trusted-substituters = [ "https://cache.nixos.org" ];
        trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
        warn-dirty = false;
        #accept-flake-config = true;
        log-lines = 25;
        auto-optimise-store = true;
        experimental-features = [ "nix-command" "flakes" "ca-derivations" "recursive-nix" ];
        trusted-users = [ "root" config.mainUser ];
        keep-outputs = true;
      };
      gc = {
        automatic = true;
        options = "--delete-older-than 21d";
        # cleans up old home-manager genrations
        dates = "weekly";
      };
    };

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
      # config tool for mice
      ratbagd.enable = true;
      xserver = {
        # system just feels a bit more responsive
        autoRepeatInterval = 20;
        autoRepeatDelay = 400;
      };
      # TODO try adding picom blur and reducing alacrity opacity
      cron = {
        enable = true;
        systemCronJobs = [
          "0 18 * * 4 /home/bbrian/Documents/P1-wiki/pullscript.sh"
          "0 23 * * 4 /home/bbrian/Documents/P1-wiki/pushscript.sh"
        ];
      };
    };


    users.users.root = {
      hashedPasswordFile = config.sops.secrets.hashedPassword.path;
      shell = pkgs.zsh;
    };
    users.users.${config.mainUser} = {
      hashedPasswordFile = config.sops.secrets.hashedPassword.path;
      isNormalUser = true;
      description = config.mainUser;
      shell = pkgs.zsh; # TODO can home-manager do this?
      extraGroups = [ "networkmanager" "wheel" ];
      packages = with pkgs; [
        picom # afaict this is needed for picom to work
        steam
        steam-run
        libgdiplus
        glxinfo
        cloudflare-warp
      ];
    };

    programs.zsh.enable = true;
    # required for nix tab completion


  };
}
