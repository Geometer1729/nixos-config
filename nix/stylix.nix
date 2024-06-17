# Programs I want this to work for
# ranger
# btop
# lazygit
# vim
# tmux
# xmobar (mostly needs a fix for the part from xmonad)
# vit (not really, needs a stylix module)
{pkgs,...}:
let
  #https://tinted-theming.github.io/base16-gallery/
  gotham = {
      base00 = "0c1014";
      base01 = "11151c";
      base02 = "091f2e";
      base03 = "0a3749";
      base04 = "245361";
      base05 = "599cab";
      base06 = "99d1ce";
      base07 = "d3ebe9";
      base08 = "c23127";
      base09 = "d26937";
      base0A = "edb443";
      base0B = "33859E";
      base0C = "2aa889";
      base0D = "195466";
      base0E = "888ca6";
      base0F = "4e5166";
    };
in
{
  stylix = {
    image = ./grub/sand.jpg;
    opacity.terminal = 0.9;
    polarity = "dark";
    base16Scheme = gotham;
    fonts = {
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
  cursor = {
    package = pkgs.simp1e-cursors;
    name = "simp1e-dark";
    size = 24;
  };
  };
}
