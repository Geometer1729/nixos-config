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
  solarized-dark = {
    base00 = "002b36";
		base01 = "073642";
		base02 = "586e75";
		base03 = "657b83";
		base04 = "839496";
		base05 = "93a1a1";
		base06 = "eee8d5";
		base07 = "fdf6e3";
		base08 = "dc322f";
		base09 = "cb4b16";
		base0A = "b58900";
		base0B = "859900";
		base0C = "2aa198";
		base0D = "268bd2";
		base0E = "6c71c4";
		base0F = "d33682";
    };
in
{
  stylix = {
    enable = true;
    image = ./grub/sand.jpg;
    opacity.terminal = 0.9;
    polarity = "dark";
    base16Scheme = solarized-dark;
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
