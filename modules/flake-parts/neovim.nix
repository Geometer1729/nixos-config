{ inputs, ... }:
{
  perSystem = { pkgs, system, lib, ... }:
    let
      nixvimLib = inputs.nixvim.lib.${system};
      nixvimModule = {
        inherit pkgs;
        module = import ../home/nvim/nixvim.nix { inherit pkgs lib; };
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
