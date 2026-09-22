# Shared definition: both GPG agents use this package in their own registry.
{ pkgs, ... }:
{
  scripts.pinentry = {
    directory = ./.;
    extras = with pkgs; [ pinentry-qt pinentry-curses ];
  };
}
