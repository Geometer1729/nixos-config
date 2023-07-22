{nixpkgs,home-manager,machines,userName,secrets}:
    let
      specialArgs = {inherit userName secrets machines;};
      homeModules = [ ./home ];
      nixModules = [ ./nix ];
      stateVersion = "22.05";
      lib = nixpkgs.lib;
    in
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
    ) machines
