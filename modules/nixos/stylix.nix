# Programs I want this to work for
# ranger
# btop
# lazygit
# vim
# tmux
# xmobar (mostly needs a fix for the part from xmonad)
# vit (not really, needs a stylix module)
{ pkgs, ... }:
{
  stylix = {
    enable = true;
    # TODO this doesn't work?
    image = ./grub/sand.jpg;
    opacity.terminal = 0.9;
    polarity = "dark"; # TODO this doesn't seem to work for some programs like pinentry
    #https://tinted-theming.github.io/base16-gallery/
    # I don't hate atelier forest
    #base16Scheme = "${pkgs.base16-schemes}/share/themes/atelier-forest.yaml";
    # AYU is pretty good
    base16Scheme = "${pkgs.base16-schemes}/share/themes/ayu-dark.yaml";
    #base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    #base16Scheme = "${pkgs.base16-schemes}/share/themes/solarized-dark.yaml";
    #base16Scheme = "${pkgs.base16-schemes}/share/themes/deep-oceanic-next.yaml";
    #base16Scheme = {
    #  base00 = "#000000";
    #  base01 = "#571dc2";
    #  base02 = "#14db49";
    #  base03 = "#403d70";
    #  base04 = "#385a70";
    #  base05 = "#384894";
    #  base06 = "#4f3a5e";
    #  base07 = "#999999";
    #  base08 = "#38372c";
    #  base09 = "#7c54b0";
    #  base0A = "#a2e655";
    #  base0B = "#9c6f59";
    #  base0C = "#323f5c";
    #  base0D = "#5e6c99";
    #  base0E = "#667d77";
    #  base0F = "#ffffff";
    #};
    #"${pkgs.base16-schemes}/share/themes/isotope.yaml";
    ##isotope //
    #override =
    #  {
    #    base0A = "#ffff00"; #yellow
    #    base0B = "#58FF1E"; # green
    #    base0E = "#bd93f9"; # purple?
    #    base0F = "#5f875f"; # brown (cringe) blue
    #  };
    fonts = {
      serif = {
        package = pkgs.nerd-fonts.hack;
        name = "Hack Nerd Font";
      };
      sansSerif = {
        package = pkgs.nerd-fonts.hack;
        name = "Hack Nerd Font";
      };
      monospace = {
        package = pkgs.nerd-fonts.hack;
        name = "Hack Nerd Font Mono";
      };
      emoji = {
        package = pkgs.nerd-fonts.hack;
        name = "Hack Nerd Font";
      };
    };
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
  };
}
