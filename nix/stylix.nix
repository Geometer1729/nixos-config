{pkgs,config,...}:
let
  solarized-dark =
{
  #https://tinted-theming.github.io/base16-gallery/
  base00 =  "002b36";
  base01 =  "073642";
  base02 =  "586e75";
  base03 =  "657b83";
  base04 =  "839496";
  base05 =  "93a1a1";
  base06 =  "eee8d5";
  base07 =  "fdf6e3";
  base08 =  "dc322f";
  base09 =  "cb4b16";
  base0A =  "b58900";
  base0B =  "859900";
  base0C =  "2aa198";
  base0D =  "268bd2";
  base0E =  "6c71c4";
  base0F =  "d33682";

};
in
{
    # Programs I want this to work for
    # ranger
    # btop (not working?)
    # vit (partially?)
    # lazygit
    # vim
    # tmux
    # xmobar
    stylix.image = ./grub/sand.jpg;
    stylix.opacity.terminal = 0.85;
    stylix.polarity = "dark";
    stylix.base16Scheme = solarized-dark // { base0F = "982ee6"; };
    stylix.fonts = {
      serif = {
        package = pkgs.nerdfonts;
        name = "Hack Nerd Font";
      };
      sansSerif = {
        package = pkgs.nerdfonts;
        name = "Hack Nerd Font";
      };
      monospace = {
        package = pkgs.nerdfonts;
        name = "Hack Nerd Font Mono";
      };
      emoji = {
        package = pkgs.nerdfonts;
        name = "Hack Nerd Font";
      };
  };
  stylix.targets.console.enable = false;

  #config.console.colors = with config.lib.stylix.colors; [
  #  base00-hex
  #  base08-hex
  #  base0B-hex
  #  base0A-hex
  #  base0D-hex
  #  base0E-hex
  #  base0C-hex
  #  base05-hex
  #  base03-hex
  #  base09-hex
  #  base01-hex
  #  base02-hex
  #  base04-hex
  #  base06-hex
  #  base0F-hex
  #  base07-hex
  #];
}
