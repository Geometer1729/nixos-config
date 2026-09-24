{ pkgs, ... }:
{
  scripts.utilities = {
    directory = ./.;
    extras = [ pkgs.libnotify ];
    overrides.ocr-region.extras = with pkgs; [
      grim
      slurp
      wayfreeze
      wl-clipboard
      (tesseract.override { enableLanguages = [ "eng" ]; })
    ];
  };
}
