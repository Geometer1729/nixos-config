{pkgs,...}:
let
  isotope =
{
  #https://tinted-theming.github.io/base16-gallery/
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
    # Programs I want this to work for
    # ranger
    # btop (not working?)
    # vit (partially?)
    # lazygit
    # vim
    # tmux
    # xmobar
    stylix.image = ./grub/sand.jpg;
    stylix.opacity.terminal = 0.8;
    stylix.polarity = "dark";
    stylix.base16Scheme = isotope // { base0A = "f7e203"; };
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
