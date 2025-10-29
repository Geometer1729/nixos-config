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
    ./icloud.nix
    ./taskchampion-client.nix
  ];
}
