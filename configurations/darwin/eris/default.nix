{ flake, pkgs, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    self.darwinModules.cloudflare
  ];

  # Set the system platform
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Set the hostname
  networking.hostName = "eris";

  # Cloudflare tunnel configuration
  cloudflare-id = "your-tunnel-id-here";

  # Set primary user for system defaults
  system.primaryUser = "bbrian";

  # Set zsh as the default shell
  programs.zsh.enable = true;

  # Configure Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@admin" ];
  };

  # Fix GID mismatch for nixbld group
  ids.gids.nixbld = 350;
  # Enable touch ID for sudo (if supported)
  # security.pam.enableSudoTouchId = true;

  # Keyboard configuration - swap caps lock and escape
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # Configure the dock
  system.defaults = {
    dock = {
      autohide = true;
      orientation = "bottom";
      show-recents = false;
      tilesize = 48;
    };

    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      ShowStatusBar = true;
    };

    NSGlobalDomain = {
      # Enable dark mode
      AppleInterfaceStyle = "Dark";
      # Show all file extensions
      AppleShowAllExtensions = true;
    };

    # Custom preferences for disabling data detectors
    CustomUserPreferences = {
      "NSGlobalDomain" = {
        # Disable data detectors (yellow highlighting) system-wide
        WebAutomaticDataDetectionEnabled = false;
      };
    };

  };

  # Home Manager integration
  users.users.bbrian.home = "/Users/bbrian";
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.bbrian = { ... }: {
      home.stateVersion = "22.05";
      home.username = "bbrian";
      home.homeDirectory = "/Users/bbrian";

      imports = with self.homeModules; [
        inputs.nixvim.homeManagerModules.nixvim

        # Reuse existing modules
        alacritty
        git
        development
        tmux
        zsh
        claude

        # Use Darwin-specific nvim module (without stylix)
        ../../../modules/home/nvim-darwin.nix
        system
      ];
    };
  };

  # Used for backwards compatibility, please read the changelog before changing
  system.stateVersion = 4;
}
