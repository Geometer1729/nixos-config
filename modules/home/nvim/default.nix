{ flake, pkgs, lib, ... }:
{
  stylix.targets.nixvim = {
    enable = true;
    #plugin = "base16-nvim";
    transparentBackground = {
      main = true;
      signColumn = true;
    };
  };
  programs.nixvim =
    (import ./nixvim.nix {
      inherit pkgs lib;
      nixpkgsSource = flake.inputs.nixpkgs;
      pluginSources = {
        inherit (flake.inputs)
          telescope-vimwiki-nvim
          nvim-luaref
          ocaml-nvim
          recover-vim
          ;
      };
    })
    // { enable = true; };

}
