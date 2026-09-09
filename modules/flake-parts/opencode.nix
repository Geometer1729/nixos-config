{ self, ... }:
{
  perSystem = { pkgs, lib, system, ... }: {
    checks = {
      opencode-plugins = (import ../home/opencode/plugins/package.nix {
        inherit lib pkgs;
      }).check;
    } // lib.optionalAttrs (system == "x86_64-linux") {
      opencode-plugin-load = import ../home/opencode/checks/load.nix {
        inherit lib pkgs;
        home = self.nixosConfigurations.am.config.home-manager.users.bbrian;
      };
    };
  };
}
