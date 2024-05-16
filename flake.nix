{
  description = "Brian's nixos config";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:r-ryantm/nixpkgs/auto-update/discord";
    #nixpkgs.url = "path:/home/bbrian/Code/nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };
    nur.url = "github:nix-community/NUR";
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    secrets.url = "path:/persist/secrets";
    persist-retro.url = "github:Geometer1729/persist-retro";
    #persist-retro.url = "path:/home/bbrian/Code/persist-retro";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, deploy-rs, secrets, ... }:
    let
      userName = "bbrian";
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      machines = import ./machines;
      inherit
        ((import ./builder.nix)
          { inherit userName nixpkgs home-manager secrets machines system pkgs inputs; })
        nixosConfigurations
        homeConfigurations
        ;
      deploy.nodes =
        (builtins.mapAttrs
          (name: conf:
            {
              hostname = name;
              profiles.${name} = {
                user = "root";
                path = deploy-rs.lib.x86_64-linux.activate.nixos conf;
              };
            }
          )
          nixosConfigurations)
      ;
    in
    {
      inherit nixosConfigurations homeConfigurations deploy;
      devShell.x86_64-linux = pkgs.mkShell
        {
          nativeBuildInputs = [ pkgs.deploy-rs ];
          packages = [
            pkgs.sumneko-lua-language-server # for nvim config stuff
            (pkgs.haskell.packages.ghc94.ghcWithPackages
              (pkgs: with pkgs;
              # TODO this is repeated
              [
                mtl
                containers
                xmonad
                xmonad-contrib
                cabal-install
                haskell-language-server
              ]
              )
            )
          ];
        };
    };
}
