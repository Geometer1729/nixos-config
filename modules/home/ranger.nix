{ pkgs, ... }:
let
  ranger-patched = pkgs.ranger.overrideAttrs (old: {
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
