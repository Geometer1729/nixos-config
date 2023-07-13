{...}:
{
  programs.alacritty.enable = true;
  programs.alacritty.settings = {
    font = {
      #normal.family = "xft:Fira Mono";
      size = 12;
    };
    draw_bold_text_with_bright_colors = true;
    window = {
      opacity=0.9;
      padding ={
        x = 3;
        y = 3;
      };
    };

    colors = {
      primary = {
        background = "#000000";
      };
      bright = {
        black = "#555555";
        red = "#FF0000";
        green = "#00FF00";
        yellow = "#FFFF00";
        blue = "#6464FF";
        magenta = "#FF00FF";
        cyan = "#00FFFF";
        white = "#FFFFFF";
      };
      normal = {
        black = "#2A2A2A";
        red = "#D80000";
        green = "#00D800";
        yellow = "#D8D800";
        blue = "#5C5CDD";
        magenta = "#DD00DD";
        cyan = "#00DDDD";
        white = "#DDDDDD";
      };
      dim = {
        black = "#000000";
        red = "#B40000";
        green = "#00AA00";
        yellow = "#AAAA00";
        blue = "#5555AA";
        magenta = "#AA00AA";
        cyan = "#00AAAA";
        white = "#AAAAAA";
      };
    };
  };
}
