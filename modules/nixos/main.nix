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

    boot.kernel.sysctl."vm.swappiness" = 1;
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
        cloudflare-warp
      ];
    };

    programs.zsh.enable = true;
    # required for nix tab completion
  };
}
