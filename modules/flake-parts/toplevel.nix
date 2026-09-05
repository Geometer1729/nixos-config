# Top-level flake glue to get our configuration working
{ inputs, lib, self, ... }:

{
  imports = [
    inputs.nixos-unified.flakeModules.default
    inputs.nixos-unified.flakeModules.autoWire
  ];
  perSystem = { self', pkgs, system, ... }: {
    # For 'nix fmt'
    formatter = pkgs.nixpkgs-fmt;

    # Enables 'nix run' to activate.
    packages.default = self'.packages.activate;

    checks = lib.optionalAttrs (system == "x86_64-linux") {
      nixos-am = self.nixosConfigurations.am.config.system.build.toplevel;
      nixos-balrog = self.nixosConfigurations.balrog.config.system.build.toplevel;
      nixos-torag = self.nixosConfigurations.torag.config.system.build.toplevel;
    };
  };
}
