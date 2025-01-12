{ inputs, ... }:
{
  perSystem = { pkgs, system, lib, ... }:
    let
      neovimWithConfig = inputs.nixvim.legacyPackages.${system}.makeNixvimWithModule {
        inherit pkgs;
        module = import ../home/nvim/nixvim.nix { inherit pkgs lib; };
      };
    in
    {
      packages.neovim = neovimWithConfig.overrideAttrs (oa: {
        meta = oa.meta // {
          description = "Neovim with NixVim configuration";
        };
      });
    };
}
