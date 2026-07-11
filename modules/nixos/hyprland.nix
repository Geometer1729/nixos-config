{ config, lib, pkgs, ... }:
let
  sessionData = config.services.displayManager.sessionData.desktops;
  hyprlandSession = pkgs.writeShellScript "greetd-hyprland" ''
    log_dir="$HOME/.local/state/greetd"
    ${pkgs.coreutils}/bin/mkdir -p "$log_dir"
    log="$log_dir/hyprland.log"
    exec >>"$log" 2>&1

    echo "== $(${pkgs.coreutils}/bin/date --iso-8601=seconds) greetd-hyprland $$ =="
    echo "USER=$USER HOME=$HOME XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-} DBUS_SESSION_BUS_ADDRESS=''${DBUS_SESSION_BUS_ADDRESS:-} XDG_SESSION_TYPE=''${XDG_SESSION_TYPE:-} XDG_CURRENT_DESKTOP=''${XDG_CURRENT_DESKTOP:-}"

    export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"
    export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"

    for _ in 1 2 3 4 5; do
      if ${pkgs.systemd}/bin/systemctl --user is-system-running --quiet 2>/dev/null; then
        break
      fi
      ${pkgs.coreutils}/bin/sleep 0.2
    done

    echo "systemd-user-state=$(${pkgs.systemd}/bin/systemctl --user is-system-running 2>&1 || true)"

    # Failed or exited Hyprland attempts can leave user targets/services active,
    # which makes the next start-hyprland attempt refuse or race user shutdown.
    ${pkgs.systemd}/bin/systemctl --user stop \
      hyprland-session.target \
      graphical-session.target \
      graphical-session-pre.target \
      hyprpaper.service \
      hypridle.service \
      waybar.service \
      2>/dev/null || true
    ${pkgs.systemd}/bin/systemctl --user reset-failed 2>/dev/null || true

    echo "starting ${pkgs.hyprland}/bin/start-hyprland"
    exec ${pkgs.hyprland}/bin/start-hyprland
  '';
  plasmaX11Session = "${pkgs.xinit}/bin/startx ${pkgs.kdePackages.plasma-workspace}/bin/startplasma-x11";
  xsessionWrapper = "${pkgs.xinit}/bin/startx ${pkgs.coreutils}/bin/env";
  greetdSessions = pkgs.runCommand "greetd-sessions" { } ''
    mkdir -p $out/share/wayland-sessions $out/share/xsessions

    cat > $out/share/wayland-sessions/hyprland.desktop <<EOF
    [Desktop Entry]
    Name=Hyprland
    Comment=Direct Hyprland session for greetd
    Exec=${hyprlandSession}
    Type=Application
    DesktopNames=Hyprland
    EOF

    ln -s ${sessionData}/share/wayland-sessions/plasma.desktop $out/share/wayland-sessions/plasma.desktop
    ln -s ${sessionData}/share/xsessions/plasmax11.desktop $out/share/xsessions/plasmax11.desktop
  '';
in
{
  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # XDG portal for Hyprland
  xdg.portal = {
    enable = true;
    # mkForce to override wayland-session.nix which adds xdg-desktop-portal-gtk (pulls in all of GNOME)
    extraPortals = lib.mkForce [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.kdePackages.xdg-desktop-portal-kde
    ];
    config.common.default = [ "hyprland" "kde" ];
  };

  services = {
    # Register Hyprland for greeters/session menus.
    displayManager = {
      defaultSession = "hyprland";
      sessionPackages = [ pkgs.hyprland ];
    };

    greetd = {
      enable = true;
      settings = {
        initial_session = {
          command = hyprlandSession;
          user = config.mainUser;
        };
        default_session.command = lib.concatStringsSep " " [
          "${pkgs.tuigreet}/bin/tuigreet"
          "--time"
          "--asterisks"
          "--user-menu"
          "--remember"
          "--remember-user-session"
          "--sessions ${lib.escapeShellArg "${greetdSessions}/share/wayland-sessions"}"
          "--xsessions ${lib.escapeShellArg "${greetdSessions}/share/xsessions"}"
          "--xsession-wrapper ${lib.escapeShellArg xsessionWrapper}"
          "--cmd ${lib.escapeShellArg plasmaX11Session}"
        ];
      };
    };

    xserver = {
      enable = true;

      # Keep your keyboard configuration
      xkb.options = "caps:swapescape";
      xkb.layout = "us";
    };
  };

  console.useXkbConfig = true;

  # Environment variables for Hyprland
  environment.sessionVariables = {
    # If your cursor becomes invisible
    WLR_NO_HARDWARE_CURSORS = "1";
    # Hint electron apps to use wayland
    NIXOS_OZONE_WL = "1";
  };
}
