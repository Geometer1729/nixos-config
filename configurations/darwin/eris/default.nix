{ flake, pkgs, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
  ];

  # Set the system platform
  nixpkgs.hostPlatform = "aarch64-darwin";
  
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Set the hostname
  networking.hostName = "eris";

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

  # System packages
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
  ];

  # Enable touch ID for sudo (if supported)
  # security.pam.enableSudoTouchId = true;

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
  };

  # Home Manager integration
  users.users.bbrian.home = "/Users/bbrian";
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.bbrian = { ... }: {
      home.stateVersion = "22.05";
      imports = [
        inputs.nixvim.homeManagerModules.nixvim
        ../../../modules/home/nvim-darwin.nix
        ../../../modules/home/git.nix
      ];

      # Core development tools
      home.packages = with pkgs; [
        ripgrep
        fd
        dust
        bat
        gh
        curl
        wget
        tree
        htop
        jq
        claude-code
        tmux
        just
      ];

      # Zsh configuration (simplified for Darwin)
      programs.zsh = {
        enable = true;
        autosuggestion.enable = true;
        enableCompletion = true;
        syntaxHighlighting.enable = true;
        autocd = true;
        defaultKeymap = "viins";
        history = {
          append = true;
          path = "$HOME/.zsh_history";
        };
        historySubstringSearch.enable = true;

        localVariables = {
          EDITOR = "nvim";
          BROWSER = "firefox";
          REPORTTIME = 1;
        };

        shellAliases = {
          rs = "exec zsh";
          ls = "ls -hN --color=auto";
          grep = "grep -E --color=auto";
          sed = "sed -E";
          la = "ls -A";
          ll = "ls -Al";
          mv = "mv -i";
          gs = "git status";
          rgi = "rg -i";
          ":q" = "exit";
          du = "dust";
          v = "nvim";
          vim = "nvim";
          vi = "nvim";
          g = "git";
          lg = "lazygit";
        };

        initExtra = ''
          # Basic vi cursor shapes
          bindkey -v
          bindkey '^R' history-incremental-search-backward
        '';
      };

      # Direnv
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      # Set session variables
      home.sessionVariables = {
        EDITOR = "nvim";
        NIX_AUTO_RUN = 1;
      };
    };
  };

  # Used for backwards compatibility, please read the changelog before changing
  system.stateVersion = 4;
}
