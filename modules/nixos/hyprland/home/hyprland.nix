{ pkgs, lib, config, osConfig, ... }:
let
  cfg = config.programs.hyprland-custom;
  scratchpads = import ./scratchpads.nix;
  scratchpadPattern = lib.concatMapStringsSep "|" (scratchpad: scratchpad.name) scratchpads;
  scratchpadBindings = map
    (scratchpad: "$mod, ${scratchpad.key}, Toggle ${scratchpad.name} scratchpad, exec, scratchPad ${scratchpad.name}")
    scratchpads;
in
{
  options.programs.hyprland-custom = {
    dualMonitor = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to use dual monitor setup";
    };

    primaryMonitor = lib.mkOption {
      type = lib.types.str;
      description = "Primary monitor configuration";
    };

    secondaryMonitor = lib.mkOption {
      type = lib.types.str;
      description = "Secondary monitor configuration (only used if dualMonitor is true)";
    };

    battery = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to show battery indicator in waybar";
    };
  };

  config = {
    # Install Hyprland-related packages
    home.packages = with pkgs; [
      hyprpaper # wallpaper daemon
      hypridle # idle daemon
      hyprlock # screen locker
      hyprpicker # color picker
      wayfreeze
      wl-clipboard # clipboard utilities
      grim # screenshot utility
      slurp # area selection for screenshots
      waybar # status bar
      xdg-desktop-portal-hyprland
      mako # notification daemon for wayland
      libnotify # notify-send command
    ];

    # Swappy configuration - auto-exit on copy like omarchy
    programs.swappy = {
      enable = true;
      settings = {
        Default = {
          save_dir = "$HOME/Pictures";
          save_filename_format = "screenshot-%Y%m%d-%H%M%S.png";
          show_panel = false;
          line_size = 5;
          text_size = 20;
          text_font = "sans-serif";
          paint_mode = "arrow";
          early_exit = true;
          fill_shape = false;
        };
      };
    };

    # Mako notification service configuration
    services.mako = {
      enable = true;
      settings = {
        # Follow the cursor to display notifications on the active monitor
        output = ""; # Empty means follow cursor/active monitor
        anchor = "top-right";
        width = 300;
        height = 150;
        margin = "10";
        padding = "15";
        border-size = 2;
        border-radius = 5;
        default-timeout = 5000;
        ignore-timeout = false;
        layer = "overlay";
        max-visible = 5;
        max-history = 50;
        sort = "-time";
        # Toggled by notification-center dnd; hidden notifications still reach history.
        "mode=do-not-disturb".invisible = true;
      };
    };

    # Hyprland configuration
    wayland.windowManager.hyprland = {
      enable = true;
      configType = "hyprlang";
      plugins = [
        #REEE I can't get plugins to build
      ];
      settings = {
        # Monitor configuration
        monitor =
          if cfg.dualMonitor then [
            cfg.primaryMonitor
            cfg.secondaryMonitor
          ] else [
            cfg.primaryMonitor
          ];

        # Input configuration
        input = {
          kb_layout = "us";
          kb_options = "caps:swapescape";
          repeat_rate = 20;
          repeat_delay = 400;

          follow_mouse = 1;
          sensitivity = 0; # -1.0 - 1.0, 0 means no modification
        };

        # General settings
        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 1;
          layout = "dwindle";
          allow_tearing = false;
        };

        # Decoration settings
        decoration = {
          rounding = 5;

          blur = {
            enabled = true;
            size = 3;
            passes = 1;
          };

          #drop_shadow = true;
          #shadow_range = 4;
          #shadow_render_power = 3;
          #"col.shadow" = "rgba(1a1a1aee)";
        };

        # Animation settings
        animations = {
          enabled = true;

          bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";

          animation = [
            "windows, 1, 7, myBezier"
            "windowsOut, 1, 7, default, popin 80%"
            "border, 1, 10, default"
            "borderangle, 1, 8, default"
            "fade, 1, 7, default"
            "workspaces, 1, 6, default"
          ];
        };

        # Layout configuration
        dwindle = {
          preserve_split = true;
        };

        #master = {
        #  new_is_master = true;
        #};

        # Misc settings - most managed by Stylix
        misc = {
          force_default_wallpaper = -1;
          #enable_swallow = true;
          #swallow_regex = ".*prismlauncher.*";
        };

        group = {
          auto_group = true;
          group_on_movetoworkspace = true;
        };

        # Workspaces - 22 workspaces total
        workspace =
          let
            primaryMonitorName = builtins.head (lib.splitString "," cfg.primaryMonitor);
            secondaryMonitorName = if cfg.dualMonitor then builtins.head (lib.splitString "," cfg.secondaryMonitor) else primaryMonitorName;
          in
          if cfg.dualMonitor then
          # Dual monitor: split workspaces between monitors
            (map (i: "${toString i}, monitor:${primaryMonitorName}") ((lib.range 1 5) ++ (lib.range 11 15))) ++
            (map (i: "${toString i}, monitor:${secondaryMonitorName}") ((lib.range 6 10) ++ (lib.range 16 22)))
          else
          # Single monitor: all workspaces on primary
            (map (i: "${toString i}, monitor:${primaryMonitorName}") (lib.range 1 22));
        # Window rules - using new 0.53 syntax with match:
        windowrule = [
          # Force prismlauncher to tile to prevent floating positioning issues with swallow
          "tile on, match:class prismlauncher"
          # Maximize messaging apps on workspace 21 (xmonad Full layout style)
          "fullscreen_state 1 0, match:class (discord|signal|slack)"

          "float on, match:class .blueman-manager-wrapped"
          "size monitor_w*0.5 monitor_h*0.5, match:class .blueman-manager-wrapped"
          "center on, match:class .blueman-manager-wrapped"
          "float on, match:title ^Wi-Fi picker$"
          "size monitor_w*0.6 monitor_h*0.65, match:title ^Wi-Fi picker$"
          "center on, match:title ^Wi-Fi picker$"
          "float on, match:title float"
          "workspace 21 silent, match:class discord"
          "workspace 21 silent, match:class signal"
          "workspace 21 silent, match:class Slack"
          "workspace 10 silent, match:title Steam"
        ] ++ map
          (rule: "${rule}, match:title ^(${scratchpadPattern})$")
          [ "float on" "size monitor_w*0.5 monitor_h*0.5" "center on" ]
        ++ map
          (workspace: "workspace ${toString workspace} silent, match:title ^Brave WS ${toString workspace}$")
          (lib.range 1 22);

        # Keybindings - translating your XMonad bindings
        "$mod" = "ALT"; # Using Alt like your XMonad setup

        # Descriptions also appear in Rofi's Keybinds mode via hyprctl binds.
        bindd = [
          # Application launchers
          "$mod, Return, Open terminal, exec, ghostty"
          "$mod, d, Open command palette, exec, rofi -show combi"
          "$mod SHIFT, d, Open password picker, exec, passmenu"
          "$mod, s, Open SSH launcher, exec, rofi -show ssh"
          "$mod, r, Run a command, exec, rofi -show run"
          "$mod SHIFT, n, Start a ticket, exec, start-ticket"
          "$mod SHIFT, Return, Open Brave window for this workspace, exec, brave-workspace-window"
          "$mod, u, Clean URL in clipboard, exec, clean-url"
          "$mod SHIFT, v, Open clipboard history, exec, clipboard-history"
          "$mod CTRL, v, Force paste clipboard by typing it, exec, force-paste"
          "$mod, e, Hold to dictate, exec, dictate start"

          # Notifications
          "$mod, i, Open notification history, exec, notification-center history"
          "$mod SHIFT, i, Restore last dismissed notification, exec, makoctl restore"
          "$mod, x, Dismiss all notifications, exec, makoctl dismiss -a"
          "$mod, z, Toggle Do Not Disturb, exec, notification-center dnd"

          # Window management
          "$mod, q, Close active window, killactive"
          "$mod SHIFT, q, Exit Hyprland, exit"
          "$mod, space, Toggle floating window, togglefloating"
          "$mod, w, Toggle maximized window, fullscreen,1"
          # TODO this works pretty badly tbh and I really wish it was automatic
          "$mod, f, Tell application it is fullscreen, fullscreenstate, -1 2"

          # Cycle to next window and maximize (xmonad Full layout style)
          "$mod, Tab, Cycle to next window and maximize, exec, hyprctl --batch 'dispatch cyclenext; dispatch fullscreen 1'"

          # Focus movement (vim-style like your XMonad)
          "$mod, h, Focus window to the left, movefocus, l"
          "$mod, l, Focus window to the right, movefocus, r"
          "$mod, k, Focus window above, movefocus, u"
          "$mod, j, Focus window below, movefocus, d"

          # Window movement
          "$mod SHIFT, h, Move window left, movewindow, l"
          "$mod SHIFT, l, Move window right, movewindow, r"
          "$mod SHIFT, k, Move window up, movewindow, u"
          "$mod SHIFT, j, Move window down, movewindow, d"

          # Workspace switching (1-9, 0, F1-F12 like your XMonad)
          "$mod, 1, Switch to workspace 1, workspace, 1"
          "$mod, 2, Switch to workspace 2, workspace, 2"
          "$mod, 3, Switch to workspace 3, workspace, 3"
          "$mod, 4, Switch to workspace 4, workspace, 4"
          "$mod, 5, Switch to workspace 5, workspace, 5"
          "$mod, 6, Switch to workspace 6, workspace, 6"
          "$mod, 7, Switch to workspace 7, workspace, 7"
          "$mod, 8, Switch to workspace 8, workspace, 8"
          "$mod, 9, Switch to workspace 9, workspace, 9"
          "$mod, 0, Switch to workspace 10, workspace, 10"
          "$mod, F1, Switch to workspace 11, workspace, 11"
          "$mod, F2, Switch to workspace 12, workspace, 12"
          "$mod, F3, Switch to workspace 13, workspace, 13"
          "$mod, F4, Switch to workspace 14, workspace, 14"
          "$mod, F5, Switch to workspace 15, workspace, 15"
          "$mod, F6, Switch to workspace 16, workspace, 16"
          "$mod, F7, Switch to workspace 17, workspace, 17"
          "$mod, F8, Switch to workspace 18, workspace, 18"
          "$mod, F9, Switch to workspace 19, workspace, 19"
          "$mod, F10, Switch to workspace 20, workspace, 20"
          "$mod, F11, Switch to workspace 21, workspace, 21"
          "$mod, F12, Switch to workspace 22, workspace, 22"

          # Move windows to workspaces
          "$mod SHIFT, 1  , Move window to workspace 1 silently, movetoworkspacesilent, 1"
          "$mod SHIFT, 2  , Move window to workspace 2 silently, movetoworkspacesilent, 2"
          "$mod SHIFT, 3  , Move window to workspace 3 silently, movetoworkspacesilent, 3"
          "$mod SHIFT, 4  , Move window to workspace 4 silently, movetoworkspacesilent, 4"
          "$mod SHIFT, 5  , Move window to workspace 5 silently, movetoworkspacesilent, 5"
          "$mod SHIFT, 6  , Move window to workspace 6 silently, movetoworkspacesilent, 6"
          "$mod SHIFT, 7  , Move window to workspace 7 silently, movetoworkspacesilent, 7"
          "$mod SHIFT, 8  , Move window to workspace 8 silently, movetoworkspacesilent, 8"
          "$mod SHIFT, 9  , Move window to workspace 9 silently, movetoworkspacesilent, 9"
          "$mod SHIFT, 0  , Move window to workspace 10 silently, movetoworkspacesilent, 10"
          "$mod SHIFT, F1 , Move window to workspace 11 silently, movetoworkspacesilent, 11"
          "$mod SHIFT, F2 , Move window to workspace 12 silently, movetoworkspacesilent, 12"
          "$mod SHIFT, F3 , Move window to workspace 13 silently, movetoworkspacesilent, 13"
          "$mod SHIFT, F4 , Move window to workspace 14 silently, movetoworkspacesilent, 14"
          "$mod SHIFT, F5 , Move window to workspace 15 silently, movetoworkspacesilent, 15"
          "$mod SHIFT, F6 , Move window to workspace 16 silently, movetoworkspacesilent, 16"
          "$mod SHIFT, F7 , Move window to workspace 17 silently, movetoworkspacesilent, 17"
          "$mod SHIFT, F8 , Move window to workspace 18 silently, movetoworkspacesilent, 18"
          "$mod SHIFT, F9 , Move window to workspace 19 silently, movetoworkspacesilent, 19"
          "$mod SHIFT, F10, Move window to workspace 20 silently, movetoworkspacesilent, 20"
          "$mod SHIFT, F11, Move window to workspace 21 silently, movetoworkspacesilent, 21"
          "$mod SHIFT, F12, Move window to workspace 22 silently, movetoworkspacesilent, 22"

          # Workspace navigation (bracket keys like XMonad)
          "$mod, bracketleft, Focus previous monitor, focusmonitor, -1"
          "$mod, bracketright, Focus next monitor, focusmonitor, +1"
          #"$mod SHIFT, bracketleft, Move window to next monitor, movewindow, mon:+1"
          #"$mod SHIFT, bracketright, Move window to previous monitor, movewindow, mon:-1"
          "$mod SHIFT, bracketleft, Move workspace to next monitor, movecurrentworkspacetomonitor,+1"
          "$mod SHIFT, bracketright, Move workspace to previous monitor, movecurrentworkspacetomonitor, -1"

          # Scratchpads (using special workspaces)
        ] ++ scratchpadBindings ++ [
          "$mod, t, Quick-add a task, exec, onScratchPad --hide-after vit quickadd quick-add-task"
          "$mod SHIFT, t, Write a quick note, exec, onScratchPad --hide-after vim quicknote quick-note"
          "$mod, p, Process tasks, exec, onScratchPad --hide-after vit process process"

          # System controls
          "$mod SHIFT, s, Suspend computer, exec, suspend-with-dpms-fix"
          "$mod SHIFT, r, Rebuild NixOS, exec, onScratchPad --hide-after sp rebuild rebuild"
          "$mod SHIFT, w, Change wallpaper, exec, systemctl --user start rotate-wallpaper.service"
          "$mod SHIFT, m, Toggle mono audio output, exec, toggle-mono-output"
          "$mod SHIFT, a, Toggle manual keep-awake (locking stays enabled), exec, keep-awake toggle"

          # Screenshots
          ", Print, Screenshot selected region and annotate, exec, sh -c 'wayfreeze & sleep 0.1; SELECTION=$(slurp); grim -g \"$SELECTION\" - | (sleep 0.1;pkill wayfreeze; swappy -f -)'"
          "SHIFT, Print, OCR selected region to clipboard, exec, ocr-region"
          "$mod, Print, Save full screenshot to Pictures, exec, grim ~/Pictures/screenshot-$(date +'%Y%m%d-%H%M%S').png"

          # Bluetooth
          "$mod SHIFT, b, Connect Bluetooth headphones, exec, bluetooth-autoconnect"
        ];

        # Release half of push-to-talk dictation.
        bindrd = [
          "$mod, e, Stop dictation and type text, exec, dictate stop"
        ];

        # Mouse bindings
        bindm = [
          "$mod, mouse:272, movewindow"
          "$mod, mouse:273, resizewindow"
        ];

        # Media keys
        bindled = [
          ", XF86AudioRaiseVolume, Raise volume, exec, pulsemixer --change-volume +1"
          ", XF86AudioLowerVolume, Lower volume, exec, pulsemixer --change-volume -1"
        ];
        bindld = [
          ", XF86AudioMute, Toggle mute, exec, pulsemixer --toggle-mute"
          ", XF86AudioPlay, Play or pause media, exec, playPause"
          ", XF86AudioNext, Next media track, exec, playerctl next"
          ", XF86AudioPrev, Previous media track, exec, playerctl previous"
          "$mod SHIFT, p, Play or pause media, exec, playPause"
          "$mod, o, Next track on all players, exec, playerctl next -a"
        ];

        # Startup applications (matching your XMonad startup)
        exec-once = [
          # waybar, hypridle, and hyprpaper are started by systemd via their respective service enables
          "mako"
          "blueman-applet"
          # Brave restores the previously named windows; the listener places them.
          "[workspace 2 silent] brave-restore-session"
          "[workspace 21 silent] env NIXOS_SPEECH=False discord"
          "[workspace 21 silent] signal-desktop"
          # Auto-connect to Bluetooth headphones
          "bluetooth-autoconnect"
          # Pester me about any swap files
          "check-swaps"
        ];
      };
    };

    # Parse the generated config with the Hyprland the session launches, so
    # option renames/removals in updates fail the build before activation.
    home.checks = [
      (pkgs.runCommand "hyprland-config-check" { nativeBuildInputs = [ osConfig.programs.hyprland.package ]; } ''
        export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR/run
        mkdir -p "$XDG_RUNTIME_DIR"
        Hyprland --verify-config -c ${config.xdg.configFile."hypr/hyprland.conf".source}
        touch $out
      '')
    ];
  };
}
