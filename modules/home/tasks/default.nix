{ pkgs, flake, ... }:
let
  inherit (pkgs) lib;
in
{
  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    config = {
      urgency."inherit" = "on";
      "news.version" = "3.4.1"; # I don't love this but it beats everything else I've tried
    };
  };

  programs.zsh.shellAliases =
    {
      ta = "task add";
      to = "taskopen";
      t = "task";
      note = "task +LATEST annotate Notes;taskopen $(task +LATEST ids)";
    };

  imports = [
    ./scripts.nix
    ./vit.nix
    ./taskchampion-client.nix
    ./gtd.nix
  ];
}
