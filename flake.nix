{
  description = "Brian's nixos config";
  inputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
      home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      deploy-rs = {
        url = "github:serokell/deploy-rs";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      secrets.url = "path:/etc/nixos/secrets" ;
    };

  outputs = { self, nixpkgs, home-manager, deploy-rs, secrets }:
    let
      userName = "bbrian";
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      machines =
        { am = {
            #TODO this could probably be automatic
            nixModules = [ ./machines/am ];
            homeModules = [ ./machines/am/home.nix ];
            ip = "10.0.0.248";
            builder = true;
            wifi = false;
            system = "x86_64-linux";
          };
          raptor = {
            nixModules = [ ./machines/raptor ];
            homeModules = [ ./machines/raptor/home.nix ];
            ip = "10.0.0.29";
            builder = false;
            wifi = true;
            system = "x86_64-linux";
          };
        } ;
      nixosConfigurations =
        (import ./builder.nix)
        { inherit userName nixpkgs home-manager secrets machines; };
      deploy.nodes =
        builtins.mapAttrs
        ( name : conf :
          { hostname = name;
            profiles.${name} = {
              user = "root";
              path = deploy-rs.lib.x86_64-linux.activate.nixos conf ;
            };
          }
        ) nixosConfigurations
        ;
    in {
      inherit nixosConfigurations deploy;
      devShell.x86_64-linux = pkgs.mkShell
        {nativeBuildInputs = [ pkgs.deploy-rs ];
          packages = [
            pkgs.sumneko-lua-language-server # for nvim config stuff
            (pkgs.haskell.packages.ghc8107.ghcWithPackages
              (pkgs : with pkgs;
                # TODO this is repeated
                [ mtl
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
    } ;
}
