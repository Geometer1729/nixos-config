{ pkgs, ... }:
let
  pick-browser = pkgs.writeShellApplication
    {
      name = "pick-browser";
      text =
        ''if [[ $1 =~ (youtube\.com|youtu\.be) ]]
          then
            exec brave "$@"
          else
            exec firefox "$@"
          fi
        '';
    };
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
          pick-browser =
            {
              type = "Application";
              name = "pick-browser";
              comment = "Picks a browser to launch based on domain";
              exec = "${pick-browser}/bin/pick-browser";
              mimeType = [ "x-scheme-handler/https" "x-scheme-handler/http" ];
            };
        };
      mimeApps =
        {
          enable = true;
          defaultApplications =
            {
              "text/html" = [ "firefox.desktop" ];
              "x-scheme-handler/https" = [ "pick-browser.desktop" ];
              "x-scheme-handler/http" = [ "pick-browser.desktop" ];
              "x-scheme-handler/spotify" = [ "spotify.desktop" ];
              "x-scheme-handler/youtube" = [ "brave.desktop" ];
              "text/plain" = [ "vim-wrapped.desktop" ];
              "inode/directory" = [ "ranger-wrapped.desktop" ];
            };
        };
    };
}
