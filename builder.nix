{nixpkgs,home-manager,machines,userName,secrets,system,pkgs}:
let
  commonSpecialArgs = {inherit userName secrets machines;};
  homeModules = [ ./home ];
  nixModules = [ ./nix ];
  stateVersion = "22.05";
  lib = nixpkgs.lib;
in
{ nixosConfigurations =
  builtins.mapAttrs
    ( hostName : opts :
      let
        user = {
          imports = homeModules ++ opts.homeModules;
          home = {inherit stateVersion;} ;
          programs.home-manager.enable = true;
          };
      in
      { nixConfig = {
          extra-substituters = [];
        };
      } //
      lib.nixosSystem
      (
       let specialArgs = commonSpecialArgs // {inherit hostName opts;};
       in
      { inherit specialArgs;
        modules = nixModules ++ opts.nixModules ++
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
    ) machines;
  homeConfigurations.${userName} =
    home-manager.lib.homeManagerConfiguration
      { inherit pkgs ;
        extraSpecialArgs = commonSpecialArgs //
          { hostName = "";
            wifi.enable = false;
          };
        modules = homeModules ++
          # some options seem to be required only for standalone home-manager
          [  { home =
              { username = userName;
                homeDirectory = "/home/${userName}";
                inherit stateVersion;
              };
          }];
      };
}
