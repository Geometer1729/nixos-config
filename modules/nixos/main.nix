{ flake, pkgs, config, ... }:
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
    time.timeZone = "America/New_York";
    i18n.defaultLocale = "en_US.UTF-8";

    nixpkgs.config.allowUnfree = true;


    security.rtkit.enable = true;
    security.sudo.wheelNeedsPassword = false;

    # services
    services = {
      openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          X11Forwarding = true;
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
      shell = pkgs.zsh; # TODO: can home-manager do this? (currently here as workaround for completion issues)
      # https://github.com/nix-community/home-manager/issues/2562
      extraGroups = [ "networkmanager" "wheel" ];
      packages = with pkgs; [
        picom # afaict this is needed for picom to work
        cloudflare-warp
      ];
    };

    programs.zsh.enable = true;
    # required for nix tab completion
  };
}
