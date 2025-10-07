# Programs I want this to work for
# vit (not really, needs a stylix module)
{ pkgs, ... }:
{
  stylix = {
    enable = true;
    # TODO this doesn't work?
    image = ./grub/sand.jpg;
    opacity.terminal = 0.9;
    polarity = "dark"; # TODO this doesn't seem to work for some programs like pinentry
    base16Scheme =
      let
        # Colors from vim-j
        black = "#000000";
        darkred = "#800000";
        darkgreen = "#008000";
        darkyellow = "#808000";
        darkblue = "#000080";
        darkmagenta = "#800080";
        darkcyan = "#008080";
        gray = "#c0c0c0";
        darkgray = "#808080";
        red = "#a8361b";
        green = "#00ff00";
        yellow = "#ffff00";
        blue = "#0000ff";
        magenta = "#ff00ff";
        cyan = "#00ffff";
        white = "#d7d4cd";
        jbrown = "#FA3B17";
        jred = "#ff0000";
        jgray = "#4e4e4e";
        jgreen = "#58FF1E";
        jdarkgreen = "#5f875f";
        jpurple = "#bd93f9";
        jblack = "#121212";
        jorange = "#FF8B00";
        jyellow = "#ffff00";

        # Colors from claude
        soft_green = "#87af87"; # Much easier on eyes than #00ff00
        soft_yellow = "#d7d75f"; # Toned down yellow
        soft_blue = "#5f87d7"; # Softer than pure blue
        soft_cyan = "#5fafaf"; # Muted cyan
        soft_purple = "#af87d7"; # Gentler purple
        dark_purple = "#6b5b95"; # Darker purple for contrast
        soft_red = "#d75f5f"; # Softer red
        darker_bg = "#1a1a1a"; # Slightly lighter background
      in
      {
        name = "joker";

        base00 = black; # Background - softer than pure black
        base01 = jgray; # Lighter background
        base02 = darkgray; # Selection background
        base03 = dark_purple; # Comments/unfocused - darker for contrast
        base04 = darkgray; # Dark foreground
        base05 = white; # Default foreground
        base06 = gray; # Light foreground
        base07 = white; # Light background
        base08 = jbrown; # Red - organge but it works
        base09 = jorange; # Orange - keep the joker orange
        base0A = jyellow; # Yellow - bring back the bright yellow
        base0B = jgreen; # Green - iconic joker green
        base0C = soft_cyan; # Cyan - keep this one softer
        base0D = jpurple; # Purple - the nice joker purple
        base0E = soft_purple; # Secondary red - softer
        base0F = jdarkgreen; # Extra color
      };
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
