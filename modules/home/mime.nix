{ pkgs, ... }:
let
  # XDG doesn't work for terminal apps
  # Aparently this is an ancient bug
  # https://gitlab.freedesktop.org/xdg/xdg-utils/-/issues/84
  # this is a workaround
  wrap = name:
    let
      pkg = pkgs.writeShellApplication
        {
          name = "wrap-${name}";
          text =
            ''if test -t 0
          then
            ${name} "$@"
          else
            alacritty -t "float" -e \
              tmux new-session -e ${name} -A -s ${name} ${name} "$@"
          fi
        '';
        };
    in
    "${pkg}/bin/wrap-${name}";
in
{
  xdg =
    {
      desktopEntries =
        {
          ranger-wrapped =
            {
              type = "Application";
              name = "ranger";
              comment = "Launches the ranger file manager";
              exec = wrap "ranger";
              mimeType = [ "inode/directory" ];
            };
          vim-wrapped =
            {
              type = "Application";
              name = "vim";
              comment = "actually nvim";
              exec = wrap "nvim";
              mimeType = [ "text/plain" ];
            };
        };
      mimeApps =
        {
          enable = true;
          defaultApplications =
            {
              "text/html" = [ "firefox.desktop" ];
              "x-scheme-handler/https" = [ "firefox.desktop" ];
              "x-scheme-handler/http" = [ "firefox.desktop" ];
              "x-scheme-handler/spotify" = [ "spotify.desktop" ];
              "text/plain" = [ "vim-wrapped.desktop" ];
              "inode/directory" = [ "ranger-wrapped.desktop" ];
            };
        };
    };
}
