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

    # Config validation lives in each module's `home.checks`, which these builds include.
    checks = lib.optionalAttrs (system == "x86_64-linux") {
      nixos-durin = self.nixosConfigurations.durin.config.system.build.toplevel;
      nixos-narvi = self.nixosConfigurations.narvi.config.system.build.toplevel;
      nixos-gimli = self.nixosConfigurations.gimli.config.system.build.toplevel;
    };
  };
}
