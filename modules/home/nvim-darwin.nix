{ pkgs, lib, ... }:
{
  programs.nixvim =
    (import ./nvim/nixvim.nix { inherit pkgs lib; })
    // { enable = true; };
}