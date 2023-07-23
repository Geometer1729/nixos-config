{nixpkgs,home-manager,machines,userName,secrets}:
    let
      commonSpecialArgs = {inherit userName secrets;};
      homeModules = [ ./home ];
      nixModules = [ ./nix ];
      stateVersion = "22.05";
      lib = nixpkgs.lib;
    in
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
       let specialArgs = commonSpecialArgs // {inherit hostName opts machines;};
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
    ) machines
