{ pkgs, ... }:
{
  scripts.utilities = {
    directory = ./.;
    extras = [ pkgs.libnotify ];
  };
}
