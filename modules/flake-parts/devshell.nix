{ inputs, ... }:
{
  imports = [
    (inputs.git-hooks + /flake-module.nix)
  ];

  perSystem = { config, lib, pkgs, ... }:
    let
      # Health checks use the host's own nvim, nix, and services, so they check
      # whichever machine runs them.
      health = (lib.evalModules {
        specialArgs = { inherit pkgs; machine.hasGui = false; };
        modules = [
          ../nixos/scripts/module.nix
          ({ config, ... }: {
            scripts.health = {
              directory = ../health;
              overrides.health.extras =
                lib.attrValues (removeAttrs config.scripts.health.packages [ "health" ]);
            };
          })
        ];
      }).config.scripts.health.packages;

      shuck = pkgs.rustPlatform.buildRustPackage {
        pname = "shuck";
        version = "0.0.38";
        src = inputs.shuck;
        cargoLock.lockFile = "${inputs.shuck}/Cargo.lock";
        cargoBuildFlags = [ "-p" "shuck-cli" ];
        doCheck = false;
      };
    in
    {
      devShells.default = pkgs.mkShell {
        name = "nixos-unified-template-shell";
        meta.description = "Shell environment for modifying this Nix configuration";
        inputsFrom = [
          config.pre-commit.devShell # See ./nix/modules/formatter.nix
        ];
        packages = with pkgs; [
          just
          nixd
          lua-language-server # for nvim config stuff
          bash-language-server
          shellcheck
          shuck
          nodejs_24
          typescript
          typescript-language-server
          yaml-language-server
          ssh-to-age
        ] ++ lib.attrValues health;

      };

      pre-commit.settings.hooks = {
        actionlint.enable = true;
        deadnix.enable = true;
        nixf-diagnose.enable = true;
        nixpkgs-fmt.enable = true;
        statix.enable = true;
        shuck = {
          enable = true;
          name = "shuck";
          entry = "${shuck}/bin/shuck check";
          files = "\\.zsh$";
        };
      };
    };
}
