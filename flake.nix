{
  description = "Brian's nixos config";

  inputs = {
    # Principle inputs (updated by `nix run .#update`)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-unified.url = "github:srid/nixos-unified";

    # Nix modules and package sets
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim/nixos-26.05";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.inputs.flake-parts.follows = "flake-parts";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    impermanence.url = "github:nix-community/impermanence";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";
    impermanence.inputs.home-manager.follows = "home-manager";
    stylix.url = "github:danth/stylix/release-26.05";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    stylix.inputs.flake-parts.follows = "flake-parts";
    stylix.inputs.nur.follows = "nur";
    firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
    firefox-addons.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    nur.url = "github:nix-community/NUR";
    nur.inputs.nixpkgs.follows = "nixpkgs";
    nur.inputs.flake-parts.follows = "flake-parts";
    homeassistant-smartrent.url = "github:ZacheryThomas/homeassistant-smartrent";
    homeassistant-smartrent.flake = false;
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    claude-code.url = "github:sadjow/claude-code-nix";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";

    # Custom source pins used by local modules.
    # These are flake inputs so `nix flake update` can move them intentionally.
    telescope-vimwiki-nvim.url = "github:ElPiloto/telescope-vimwiki.nvim";
    telescope-vimwiki-nvim.flake = false;
    nvim-luaref.url = "github:milisims/nvim-luaref";
    nvim-luaref.flake = false;
    ocaml-nvim.url = "github:andreypopp/ocaml.nvim";
    ocaml-nvim.flake = false;
    recover-vim.url = "github:chrisbra/Recover.vim";
    recover-vim.flake = false;
    zsh-nix-shell.url = "github:chisui/zsh-nix-shell";
    zsh-nix-shell.flake = false;

    # Work
    mighty-rearranger.url = "git+ssh://git@github.com/geosurge-ai/mighty-rearranger.git";
    mighty-rearranger.inputs.nixpkgs.follows = "nixpkgs";

    # PrismLauncher nightly for new auth system
    prismlauncher.url = "github:PrismLauncher/PrismLauncher/develop";
    prismlauncher.inputs.nixpkgs.follows = "nixpkgs";

    # XLibre - X11 fork replacing Xorg
    xlibre-overlay.url = "git+https://codeberg.org/takagemacoed/xlibre-overlay?ref=dev-for-26.05";
    #the follow breaks everything
    #xlibre-overlay.inputs.nixpkgs.follows = "nixpkgs";
    xlibre-overlay.inputs.flake-parts.follows = "flake-parts";

  };

  # Wired using https://nixos-unified.org/autowiring.html
  outputs = inputs:
    inputs.nixos-unified.lib.mkFlake
      { inherit inputs; root = ./.; };
}
