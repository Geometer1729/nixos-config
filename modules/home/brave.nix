{ flake, pkgs, ... }:
let
  inherit (flake) inputs;
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  brave = unstable.brave-origin.override {
    commandLineArgs = "--ozone-platform=wayland --profile-directory=Default";
  };

  restoreSession = pkgs.writeShellApplication {
    name = "brave-restore-session";
    runtimeInputs = [ pkgs.coreutils pkgs.jq ];
    text = ''
      preferences="$HOME/.config/BraveSoftware/Brave-Origin/Default/Preferences"
      if [[ -f "$preferences" ]] \
        && [[ "$(jq -r '.profile.exit_type // empty' "$preferences")" == Crashed ]]; then
        temporary=$(mktemp "''${preferences}.XXXXXX")
        trap 'rm -f "$temporary"' EXIT
        jq '.profile.exit_type = "Normal"' "$preferences" > "$temporary"
        chmod --reference="$preferences" "$temporary"
        mv "$temporary" "$preferences"
        trap - EXIT
      fi

      exec ${brave}/bin/brave-origin --restore-last-session
    '';
  };

  workspaceWindow = pkgs.writeShellApplication {
    name = "brave-workspace-window";
    runtimeInputs = [ pkgs.hyprland pkgs.jq ];
    text = ''
      workspace="''${1:-$(hyprctl activeworkspace -j | jq -r .id)}"
      if ! [[ "$workspace" =~ ^([1-9]|1[0-9]|2[0-2])$ ]]; then
        echo "brave-workspace-window: expected workspace 1-22, got '$workspace'" >&2
        exit 2
      fi

      if [[ $# -gt 0 ]]; then
        shift
      fi
      exec ${brave}/bin/brave-origin \
        --new-window \
        --window-name="Brave WS $workspace" \
        "$@"
    '';
  };

  xdgOpen = pkgs.writeShellApplication {
    name = "brave-xdg-open";
    text = ''
      if [[ $# -eq 0 ]]; then
        exec ${brave}/bin/brave-origin
      fi

      for url in "$@"; do
        case "$url" in
          http://linear.app/*|https://linear.app/*|http://*.linear.app/*|https://*.linear.app/*)
            ${brave}/bin/brave-origin --container=Work "$url" &
            ;;
          *)
            ${brave}/bin/brave-origin "$url" &
            ;;
        esac
      done
      wait
    '';
  };

  placeWorkspaceWindows = pkgs.writeShellApplication {
    name = "brave-place-workspace-windows";
    runtimeInputs = [ pkgs.findutils pkgs.hyprland pkgs.jq pkgs.socat ];
    text = ''
      socket=""
      while [[ -z "$socket" ]]; do
        while IFS= read -r candidate; do
          signature=$(basename "$(dirname "$candidate")")
          if HYPRLAND_INSTANCE_SIGNATURE="$signature" hyprctl clients -j \
            >/dev/null 2>&1; then
            socket="$candidate"
            break
          fi
        done < <(find "$XDG_RUNTIME_DIR/hypr" -mindepth 2 -maxdepth 2 \
          -name .socket2.sock -print 2>/dev/null || true)
        [[ -n "$socket" ]] || sleep 1
      done
      export HYPRLAND_INSTANCE_SIGNATURE
      HYPRLAND_INSTANCE_SIGNATURE=$(basename "$(dirname "$socket")")

      place_window() {
        local address="$1"
        local title="$2"

        if [[ "$title" =~ ^Brave\ WS\ ([1-9]|1[0-9]|2[0-2])$ ]]; then
          hyprctl dispatch movetoworkspacesilent \
            "''${BASH_REMATCH[1]},address:$address" >/dev/null
        fi
      }

      # Place windows which were mapped before this service connected.
      while IFS=$'\t' read -r address title; do
        place_window "$address" "$title"
      done < <(hyprctl clients -j | jq -r '.[] | [.address, .title] | @tsv')

      while IFS= read -r event; do
        case "$event" in
          openwindow\>\>*)
            payload="''${event#openwindow>>}"
            address="''${payload%%,*}"
            payload="''${payload#*,}"
            payload="''${payload#*,}"
            title="''${payload#*,}"
            place_window "0x$address" "$title"
            ;;
          windowtitlev2\>\>*)
            payload="''${event#windowtitlev2>>}"
            address="''${payload%%,*}"
            title="''${payload#*,}"
            place_window "0x$address" "$title"
            ;;
        esac
      done < <(socat -u "UNIX-CONNECT:$socket" -)
      exit 1
    '';
  };

  externalExtension = {
    force = true;
    text = builtins.toJSON {
      external_update_url = "https://clients2.google.com/service/update2/crx";
    };
  };
in
{
  programs.brave = {
    enable = true;
    package = brave;
  };

  home.packages = [ restoreSession workspaceWindow xdgOpen placeWorkspaceWindows ];

  # Home Manager assumes every programs.brave package uses Brave-Browser.
  # Origin has a distinct data directory, so install its extensions explicitly.
  xdg.configFile = {
    "BraveSoftware/Brave-Origin/External Extensions/dbepggeogbaibhgnhhndojpepiihcmeb.json" =
      externalExtension; # Vimium
    "BraveSoftware/Brave-Origin/External Extensions/nffaoalbilbmmfgbnbgppjihopabppdk.json" =
      externalExtension; # Video Speed Controller
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "brave-xdg.desktop";
      "x-scheme-handler/http" = "brave-xdg.desktop";
      "x-scheme-handler/https" = "brave-xdg.desktop";
      "application/xhtml+xml" = "brave-xdg.desktop";
    };
  };

  xdg.desktopEntries.brave-xdg = {
    name = "Brave Origin";
    comment = "Browse the Web";
    exec = "brave-xdg-open %U";
    icon = "brave-origin";
    categories = [ "Network" "WebBrowser" ];
    mimeType = [
      "text/html"
      "application/xhtml+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
  };

  systemd.user.services.brave-place-workspace-windows = {
    Unit = {
      Description = "Place named Brave windows on their labeled Hyprland workspaces";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${placeWorkspaceWindows}/bin/brave-place-workspace-windows";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
