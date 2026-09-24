# Top-level flake glue to get our configuration working
{ inputs, lib, self, ... }:

{
  imports = [
    inputs.nixos-unified.flakeModules.default
    inputs.nixos-unified.flakeModules.autoWire
  ];
  perSystem = { self', pkgs, system, ... }:
    let
      hyprlandHosts = lib.filterAttrs
        (_: nixos: nixos.config.home-manager.users.bbrian.wayland.windowManager.hyprland.enable or false)
        self.nixosConfigurations;
      hyprlandChecks = lib.mapAttrs'
        (host: nixos: lib.nameValuePair "hyprland-config-${host}" (pkgs.callPackage ../nixos/hyprland/config-check.nix {
          hyprland = nixos.config.programs.hyprland.package;
          config = nixos.config.home-manager.users.bbrian.xdg.configFile."hypr/hyprland.conf".source;
        }))
        hyprlandHosts;
    in
    {
      # For 'nix fmt'
      formatter = pkgs.nixpkgs-fmt;

      # Enables 'nix run' to activate.
      packages.default = self'.packages.activate;

      checks = lib.optionalAttrs (system == "x86_64-linux") ({
        script-modules = pkgs.callPackage ../nixos/scripts/tests.nix { };
        keep-awake = pkgs.callPackage ../nixos/keep-awake/tests.nix {
          inherit (self.nixosConfigurations.am.config.scripts.keep-awake.packages) keep-awake;
        };
        nixos-am = self.nixosConfigurations.am.config.system.build.toplevel;
        nixos-balrog = self.nixosConfigurations.balrog.config.system.build.toplevel;
        nixos-torag = self.nixosConfigurations.torag.config.system.build.toplevel;
      } // hyprlandChecks);
    };
}
