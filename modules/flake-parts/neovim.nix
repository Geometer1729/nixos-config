{ inputs, ... }:
{
  perSystem = { pkgs, system, lib, ... }:
    let
      pkgsForNixvim = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) [ "vim-hoogle" ];
      };
      nixvimLib = inputs.nixvim.lib.${system};
      nixvimModule = {
        pkgs = pkgsForNixvim;
        module = import ../home/nvim/nixvim.nix {
          pkgs = pkgsForNixvim;
          inherit lib;
          nixpkgsSource = inputs.nixpkgs;
        };
      };
      neovimWithConfig = inputs.nixvim.legacyPackages.${system}.makeNixvimWithModule nixvimModule;
    in
    {
      packages.neovim = neovimWithConfig.overrideAttrs (oa: {
        meta = oa.meta // {
          description = "Neovim with NixVim configuration";
        };
      });

      checks.neovim-config = nixvimLib.check.mkTestDerivationFromNixvimModule nixvimModule;
    };
}
