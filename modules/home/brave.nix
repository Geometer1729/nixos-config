{ config, flake, pkgs, ... }:
let
  inherit (flake) inputs;
  inherit (config.lib.stylix) colors;
  component = name: channel: builtins.fromJSON colors."${name}-rgb-${channel}";
  rgb = name: map (component name) [ "r" "g" "b" ];
  # base03 works as an accent but is overpowering as the window frame.
  half = name: map (c: c / 2) (rgb name);
  # Container badge colors are SkColors: signed 32-bit ARGB, alpha 0xFF.
  skColor = name: 65536 * component name "r" + 256 * component name "g" + component name "b" - 16777216;
  workContainerColor = toString (skColor "base04");
  braveTheme = pkgs.writeTextDir "manifest.json" (builtins.toJSON {
    manifest_version = 3;
    name = "Stylix Joker";
    version = "1.0";
    # The active tab is painted with the toolbar color, so toolbar must
    # contrast with frame or pinned tabs are indistinguishable.
    # Purple frame, black active tab, joker green accents.
    theme.colors = {
      frame = half "base03";
      frame_inactive = rgb "base01";
      background_tab = half "base03";
      background_tab_inactive = rgb "base01";
      tab_text = rgb "base0B";
      tab_background_text = rgb "base06";
      tab_background_text_inactive = rgb "base04";
      toolbar = rgb "base00";
      toolbar_text = rgb "base05";
      toolbar_button_icon = rgb "base0B";
      bookmark_text = rgb "base04";
      button_background = rgb "base01";
      omnibox_background = rgb "base01";
      omnibox_text = rgb "base06";
      ntp_background = rgb "base00";
      ntp_text = rgb "base05";
      ntp_link = rgb "base0B";
      ntp_header = half "base03";
    };
  });
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  brave = unstable.brave-origin.override {
    commandLineArgs = "--ozone-platform=wayland --profile-directory=Default --load-extension=${braveTheme}";
  };

  restoreSession = pkgs.writeShellApplication {
    name = "brave-restore-session";
    runtimeInputs = [ pkgs.coreutils pkgs.jq ];
    text = ''
      preferences="$HOME/.config/BraveSoftware/Brave-Origin/Default/Preferences"
      if [[ -f "$preferences" ]] \
        && jq -e '
          .profile.exit_type == "Crashed"
          or .browser.theme.color_scheme != 2
          or .browser.theme.color_scheme2 != 2
          or .browser.theme.color_variant != 3
          or .browser.theme.color_variant2 != 3
          or .brave.show_side_panel_button != false
          or .brave.location_bar_is_wide != true
          or .brave.ai_chat.show_toolbar_button != false
          or .brave.rewards.show_brave_rewards_button_in_location_bar != false
          or .brave.wallet.show_wallet_icon_on_toolbar != false
          or .brave_vpn.show_button != false
          or .brave.today.should_show_toolbar_button != false
          or .media_router.enable_media_router != false
          or .brave.enable_media_router_on_restart != false
          or (.brave.containers.used // {} | any(.[]; .name == "Work" and .background_color != ${workContainerColor}))
        ' "$preferences" >/dev/null; then
        temporary=$(mktemp "''${preferences}.XXXXXX")
        trap 'rm -f "$temporary"' EXIT
        jq '
          if .profile.exit_type == "Crashed" then
            .profile.exit_type = "Normal"
          else . end
          | .browser.theme.color_scheme = 2
          | .browser.theme.color_scheme2 = 2
          | .browser.theme.color_variant = 3
          | .browser.theme.color_variant2 = 3
          | .brave.show_side_panel_button = false
          | .brave.location_bar_is_wide = true
          | .brave.ai_chat.show_toolbar_button = false
          | .brave.rewards.show_brave_rewards_button_in_location_bar = false
          | .brave.wallet.show_wallet_icon_on_toolbar = false
          | .brave_vpn.show_button = false
          | .brave.today.should_show_toolbar_button = false
          | .media_router.enable_media_router = false
          | .brave.enable_media_router_on_restart = false
          | .brave.containers.used = ((.brave.containers.used // {}) | map_values(if .name == "Work" then .background_color = ${workContainerColor} else . end))
        ' "$preferences" > "$temporary"
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
  browserpassNative = pkgs.writeShellApplication {
    name = "browserpass-native";
    text = ''
      export PASSWORD_STORE_DIR=${config.home.homeDirectory}/password-store
      export PINENTRY_USER_DATA=gui
      exec ${pkgs.browserpass}/bin/browserpass "$@"
    '';
  };
  browserpassManifest =
    let
      manifest = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.readFile
        "${pkgs.browserpass}/lib/browserpass/hosts/chromium/com.github.browserpass.native.json"));
    in
    pkgs.writeText "com.github.browserpass.native.json" (builtins.toJSON (manifest // {
      path = "${browserpassNative}/bin/browserpass-native";
    }));
in
{
  programs.brave = {
    enable = true;
    package = brave;
  };

  home.packages = [ pkgs.browserpass restoreSession workspaceWindow xdgOpen placeWorkspaceWindows ];

  # Home Manager assumes every programs.brave package uses Brave-Browser.
  # Origin has a distinct data directory, so install its extensions explicitly.
  xdg.configFile = {
    "BraveSoftware/Brave-Origin/External Extensions/dbepggeogbaibhgnhhndojpepiihcmeb.json" =
      externalExtension; # Vimium
    "BraveSoftware/Brave-Origin/External Extensions/nffaoalbilbmmfgbnbgppjihopabppdk.json" =
      externalExtension; # Video Speed Controller
    "BraveSoftware/Brave-Origin/External Extensions/naepdomgkenhinolocfifgehidddafch.json" =
      externalExtension; # Browserpass
    "BraveSoftware/Brave-Origin/NativeMessagingHosts/com.github.browserpass.native.json".source =
      browserpassManifest;
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
