{
  description = "Brian's nixos config";
  inputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
      home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      secrets.url = "path:/etc/nixos/secrets" ;
    };

  outputs = { self, nixpkgs, home-manager, secrets }:
    let
      userName = "bbrian";
      specialArgs = {inherit userName secrets;};
      homeModules =
        [ ./modules/alacritty.nix
          ./modules/sway.nix
          ./modules/home.nix
          ./modules/scripts
          ./modules/git.nix
          ./modules/nvim
          ./modules/xmobar
          ./modules/xmonad/home.nix
          ./modules/zsh
        ];
      nixModules =
        [ ./modules/boot.nix
          ./modules/configuration.nix
          ./modules/xmonad
          ./modules/work.nix
        ];

      system = "x86_64-linux";
      stateVersion = "22.05";
      pkgs = import <nixpkgs> {
        inherit system;
        config.allowUnfree = true;
      };
      lib = nixpkgs.lib;
    in {
      devShell.x86_64-linux = pkgs.mkShell
        {nativeBuildInputs = [ ];
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
      nixosConfigurations =
        builtins.mapAttrs
        ( hostName : ops :
          let
            user = {
              imports = homeModules ++ ops.homeModules;
              home = {inherit stateVersion;} ;
              programs.home-manager.enable = true;
              };
          in
          { nixConfig = {
              extra-substituters = [];
            };
          } //
          lib.nixosSystem
          { specialArgs =
              specialArgs
              // {inherit hostName;}
              // ops;
            modules = nixModules ++ ops.nixModules ++
             [ {system = {inherit stateVersion;};}
               home-manager.nixosModules.home-manager {
                 home-manager ={
                   extraSpecialArgs = specialArgs;
                   useGlobalPkgs = true;
                   useUserPackages = true;
                   users = {
                     root = user;
                     ${userName} = user;
                   };
                 };
               }
             ];
          }
        )
        { am = {
            nixModules =
              [ ./modules/hardware/am.nix #TODO this could probably be automatic
                ./modules/perMachine/am.nix
              ];
            homeModules =
              [ ./modules/perMachine/am_home.nix
              ];
            isLaptop = false;
          };
          raptor = {
            nixModules =
              [ ./modules/hardware/raptor.nix
                ./modules/perMachine/raptor.nix
              ];
            homeModules =
              [ ./modules/perMachine/raptor_home.nix
              ];
            isLaptop = true;
          };
        } ;
    } ;
}
