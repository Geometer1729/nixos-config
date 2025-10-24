{ inputs, ... }:
{
  imports = [
    (inputs.git-hooks + /flake-module.nix)
  ];

  perSystem = { config, pkgs, ... }: {
    devShells.default = pkgs.mkShell {
      name = "nixos-unified-template-shell";
      meta.description = "Shell environment for modifying this Nix configuration";
      inputsFrom = [
        config.pre-commit.devShell # See ./nix/modules/formatter.nix
      ];
      packages = with pkgs; [
        just
        nixd
        sumneko-lua-language-server # for nvim config stuff
      ];

    };

    pre-commit.settings.hooks = {
      nixpkgs-fmt.enable = true;
    };
  };
}
