{ pkgs, ... }:
{
  programs.hyprlock = {
    enable = true;
    settings.general.ignore_empty_input = true;
  };
}
