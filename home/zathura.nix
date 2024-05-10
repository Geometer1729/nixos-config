{ ... }:
{
  # pdf reader
  programs.zathura = {
    enable = true;
    options = {
      recolor = true;
      # darkmode
      recolor-darkcolor = "#dcdccc";
      recolor-lightcolor = "#1f1f1f";
    };
  };
}
