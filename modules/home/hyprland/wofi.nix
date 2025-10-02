{ pkgs, ... }:
{
  # wofi launcher configuration
  programs.wofi = {
    enable = true;
    settings = {
      width = 600;
      height = 400;
      location = "center";
      show = "drun";
      prompt = "Search...";
      filter_rate = 100;
      allow_markup = true;
      no_actions = true;
      halign = "fill";
      orientation = "vertical";
      content_halign = "fill";
      insensitive = true;
      allow_images = true;
      image_size = 40;
      gtk_dark = true;
    };

    style = ''
      window {
        margin: 0px;
        border: 2px solid #64727D;
        background-color: rgba(43, 48, 59, 0.9);
        border-radius: 5px;
      }

      #input {
        margin: 5px;
        border: none;
        color: #ffffff;
        background-color: rgba(100, 114, 125, 0.5);
        border-radius: 3px;
      }

      #inner-box {
        margin: 5px;
        border: none;
        background-color: transparent;
      }

      #outer-box {
        margin: 5px;
        border: none;
        background-color: transparent;
      }

      #scroll {
        margin: 0px;
        border: none;
      }

      #text {
        margin: 5px;
        border: none;
        color: #ffffff;
      }

      #entry {
        margin: 2px;
        padding: 5px;
        border: none;
        border-radius: 3px;
      }

      #entry:selected {
        background-color: #64727D;
      }

      #text:selected {
        color: #ffffff;
      }
    '';
  };
}
