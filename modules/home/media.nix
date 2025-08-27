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
    #gimp  # Temporarily disabled - build issues in latest nixpkgs
    #fixed in https://github.com/NixOS/nixpkgs/pull/425710

    # Document viewing
    zathura # pdf

    # Calendar
    calcurse

    anki-bin # flashcards (binary version avoids build issues)
  ];
}
