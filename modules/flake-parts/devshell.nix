{ inputs, ... }:
{
  imports = [
    (inputs.git-hooks + /flake-module.nix)
  ];

  perSystem = { config, pkgs, ... }:
    let
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
        ];

      };

      pre-commit.settings.hooks = {
        actionlint.enable = true;
        deadnix.enable = true;
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
