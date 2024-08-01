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
    isotope =
    {
      base00 = "000000";
      base01 = "404040";
      base02 = "606060";
      base03 = "808080";
      base04 = "c0c0c0";
      base05 = "d0d0d0";
      base06 = "e0e0e0";
      base07 = "ffffff";
      base08 = "ff0000";
      base09 = "ff9900";
      base0A = "ff0099";
      base0B = "33ff00";
      base0C = "00ffff";
      base0D = "0066ff";
      base0E = "cc00ff";
      base0F = "3300ff";
    };
in
{
  stylix = {
    enable = true;
    image = ./grub/sand.jpg;
    opacity.terminal = 0.9;
    polarity = "dark";
    #https://tinted-theming.github.io/base16-gallery/
    base16Scheme = isotope //
    {
      #base08 = ""; #red
      #base09 = ""; #orange
      base0A = "#ffff00"; #yellow
      base0B = "#58FF1E"; # green
      #base0C = ""; # cyan
      #base0D = "#ffffff"; # blue
      base0E = "#bd93f9"; # purple?
      base0F = "#5f875f"; # brown (cringe) blue
    };
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
