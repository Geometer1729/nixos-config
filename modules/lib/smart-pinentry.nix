{ pkgs }:
pkgs.writeShellApplication {
  name = "pinentry";
  text = ''
    if [[ "''${PINENTRY_USER_DATA:-}" == gui ]] \
      && [[ -n "''${WAYLAND_DISPLAY:-}" || -n "''${DISPLAY:-}" ]]; then
      exec ${pkgs.pinentry-qt}/bin/pinentry-qt "$@"
    fi

    exec ${pkgs.pinentry-curses}/bin/pinentry-curses "$@"
  '';
}
