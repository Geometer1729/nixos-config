{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Video
    ffmpeg
    vlc

    # Audio
    spotify
    ncspot
    pulsemixer
    playerctl # play/pause controls

    # Image
    feh # sets background
    sxiv # simple x image viewer
    imagemagick
    gimp

    # Document viewing
    zathura # pdf

    # Calendar
    calcurse
  ];
}
