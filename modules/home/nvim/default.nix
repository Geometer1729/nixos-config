{ pkgs, lib, ... }:
{
  stylix.targets.nixvim = {
    enable = true;
    plugin = "base16-nvim";
    transparentBackground = {
      main = true;
      signColumn = true;
    };
  };
  programs.nixvim =
    (import ./nixvim.nix { inherit pkgs lib; })
    // { enable = true; };
}
