{ config, pkgs, ... }:
{
  scripts.media = {
    directory = ./.;
    extras = with pkgs; [
      calcurse
      playerctl
      config.programs.rofi.package
      pipewire
      pulseaudioFull
    ];
  };

  home.packages = with pkgs; [
    # Video
    ffmpeg
    vlc

    # Audio
    spotify
    ncspot
    pulsemixer
    playerctl # play/pause controls
    mpv # used by anki for audio playback

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
