{ pkgs, ... }:
let
  ranger-patched = pkgs.ranger.overrideAttrs (old: {
    # Kitty graphics through tmux, with a file probe compatible with Ghostty.
    # Omitting the optional S avoids Ghostty 1.3.1's exact-size read failure.
    patches = (old.patches or [ ]) ++ [ ./ranger-tmux-kitty.patch ];
  });
in
{
  home.packages = [ ranger-patched ];

  xdg.configFile."ranger/rc.conf".text = ''
    set preview_images true
    set preview_images_method kitty
  '';
}
