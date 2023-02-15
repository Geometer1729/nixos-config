# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{ config, pkgs, userName, hostName, secrets, ... }:

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
    ];

  #steam needs this
  hardware.opengl.driSupport32Bit = true;
  hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
  hardware.pulseaudio.support32Bit = true;

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
      substituters = [  "https://mlabs.cachix.org" ];
      trusted-substituters = [ "https://mlabs.cachix.org" ];
      trusted-public-keys =
        [ "mlabs.cachix.org-1:gStKdEqNKcrlSQw5iMW6wFCj3+b+1ASpBVY2SYuNV2M=" ];
      warn-dirty = false;
      #accept-flake-config = true;
      log-lines = 25;
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" "ca-derivations" "recursive-nix" ];
      trusted-users = [ "root" userName ];
    };
    gc = {
      automatic = true;
      dates = "daily";
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
      bumblebee
      glxinfo
    ];
  };

  programs.zsh.enable = true;
  # required for nix tab completion

}
