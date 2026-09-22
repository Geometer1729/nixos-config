{ pkgs, ... }:
{
  # These commands describe this fleet rather than a reusable application.
  scripts.fleet = {
    directory = ./.;
    extras = with pkgs; [ hostname nix ];
  };
}
