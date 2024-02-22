{ pkgs, userName, hostName, secrets, ... }:

{

  networking = {
    inherit hostName;
    hosts =
    {
      "${secrets.jsh.ip}" = [ "jsh.gov" ] ;
    };
  };

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.utf8";

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays =
    [ (final: prev: {
        dmenu = prev.dmenu.overrideAttrs
          (old: {src = ./dmenu-4.9 ;});
      })
      (final: prev: {
        gotop = prev.gotop.overrideAttrs
        (old: { patches = [ ./gotop.patch ]; });
        # fix by gardockt on github
      })
      (final: prev: {
        flameshot = prev.flameshot.overrideAttrs
          (old: let
              version = "11.0.0";
              # seems to fix clipboard issue
              # issue is not consistant so it's hard to bisect
            in
            { inherit version;
              src = final.fetchFromGitHub {
                owner = "flameshot-org";
                repo = "flameshot";
                rev = "v${version}";
                sha256 = "sha256-SlnEXW3Uhdgl0icwYyYsKQOcYkAtHpAvL6LMXBF2gWM=";
              };
            }
          );
      })
    ];

  #steam needs this
  hardware =
  {
    pulseaudio.support32Bit = true;
    opengl = {
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = [ pkgs.amdvlk ];
      extraPackages32 = with pkgs.pkgsi686Linux; [ libva amdvlk ];
    };
  };


  #downloads as a tmpfs
  fileSystems."/home/${userName}/Downloads" =
    { device = "none";
      fsType = "tmpfs";
    };

  nix={
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
      options="--delete-older-than 21d";
      # cleans up old home-manager genrations
      dates = "weekly";
    };
  };

  # Sound
  sound.enable = true;
  hardware.pulseaudio.enable = false;

  security.rtkit.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # services
  services ={
    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
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


  users.users.root.shell = pkgs.zsh;
  users.users.${userName} = {
    isNormalUser = true;
    description = userName;
    shell = pkgs.zsh; # TODO can home-manager do this?
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      picom # afaict this is needed for picom to work
      steam
      steam-run
      libgdiplus
      #bumblebee
      #glxinfo
    ];
  };

  programs.zsh.enable = true;
  # required for nix tab completion

}
