# Programs I want this to work for
# ranger
# btop
# lazygit
# vim
# tmux
# xmobar (mostly needs a fix for the part from xmonad)
# vit (not really, needs a stylix module)
{pkgs,...}:
{
  stylix = {
    enable = true;
    image = ./grub/sand.jpg;
    opacity.terminal = 0.9;
    polarity = "dark"; # TODO this doesn't seem to work
    #https://tinted-theming.github.io/base16-gallery/
    base16Scheme ="${pkgs.base16-schemes}/share/themes/isotope.yaml";
      #isotope //
    override =
      {
        base0A = "#ffff00"; #yellow
        base0B = "#58FF1E"; # green
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
