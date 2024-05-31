{pkgs,config,...}:
let
  gotham =
{
  #https://tinted-theming.github.io/base16-gallery/
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
    stylix.base16Scheme = gotham ;#// { base0F = "982ee6"; };
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
}
