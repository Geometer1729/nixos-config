{ pkgs, lib, config, osConfig, flake, ... }:
let
  cfg = config.programs.hyprland-custom;
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

    home.pointerCursor = {
      hyprcursor.enable = true;
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
        sort = "-time";
      };
    };

    # Hyprland configuration
    wayland.windowManager.hyprland = {
      enable = true;
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
          pseudotile = true;
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
          # firefox handles this poorly it's not really worth it
          #"suppressevent fullscreen, match:class firefox"
          # Force prismlauncher to tile to prevent floating positioning issues with swallow
          "tile on, match:class prismlauncher"
          ## Auto-group Discord and Signal on workspace 21
          "group set invade, match:class (discord|signal|slack)"

          "float on, match:class .blueman-manager-wrapped"
          "size monitor_w*0.5 monitor_h*0.5, match:class .blueman-manager-wrapped"
          "center on, match:class .blueman-manager-wrapped"
          "float on, match:title float"
          "workspace 21 silent, match:class discord"
          "workspace 21 silent, match:class signal"
          "workspace 21 silent, match:class Slack"
          "workspace 10 silent, match:title Steam"
        ];

        # Keybindings - translating your XMonad bindings
        "$mod" = "ALT"; # Using Alt like your XMonad setup

        bind = [
          # Application launchers
          "$mod, Return, exec, alacritty"
          "$mod, d, exec, rofi -show drun"
          "$mod, s, exec, rofi -show ssh"
          "$mod, r, exec, rofi -show run"

          # Window management
          "$mod, q, killactive"
          "$mod SHIFT, q, exit"
          "$mod, space, togglefloating"
          "$mod, w, fullscreen,1"
          # TODO this works pretty badly tbh and I really wish it was automatic
          "$mod, f, fullscreenstate, -1 2"

          # Group management (tabbed windows)
          "$mod, g, togglegroup"
          "$mod, Tab, exec, hypr-smart-tab"
          "$mod SHIFT, Tab, changegroupactive, b"

          # Focus movement (vim-style like your XMonad)
          "$mod, h, movefocus, l"
          "$mod, l, movefocus, r"
          "$mod, k, movefocus, u"
          "$mod, j, movefocus, d"

          # Window movement
          "$mod SHIFT, h, movewindow, l"
          "$mod SHIFT, l, movewindow, r"
          "$mod SHIFT, k, movewindow, u"
          "$mod SHIFT, j, movewindow, d"

          # Workspace switching (1-9, 0, F1-F12 like your XMonad)
          "$mod, 1, workspace, 1"
          "$mod, 2, workspace, 2"
          "$mod, 3, workspace, 3"
          "$mod, 4, workspace, 4"
          "$mod, 5, workspace, 5"
          "$mod, 6, workspace, 6"
          "$mod, 7, workspace, 7"
          "$mod, 8, workspace, 8"
          "$mod, 9, workspace, 9"
          "$mod, 0, workspace, 10"
          "$mod, F1, workspace, 11"
          "$mod, F2, workspace, 12"
          "$mod, F3, workspace, 13"
          "$mod, F4, workspace, 14"
          "$mod, F5, workspace, 15"
          "$mod, F6, workspace, 16"
          "$mod, F7, workspace, 17"
          "$mod, F8, workspace, 18"
          "$mod, F9, workspace, 19"
          "$mod, F10, workspace, 20"
          "$mod, F11, workspace, 21"
          "$mod, F12, workspace, 22"

          # Move windows to workspaces
          "$mod SHIFT, 1  , movetoworkspacesilent, 1"
          "$mod SHIFT, 2  , movetoworkspacesilent, 2"
          "$mod SHIFT, 3  , movetoworkspacesilent, 3"
          "$mod SHIFT, 4  , movetoworkspacesilent, 4"
          "$mod SHIFT, 5  , movetoworkspacesilent, 5"
          "$mod SHIFT, 6  , movetoworkspacesilent, 6"
          "$mod SHIFT, 7  , movetoworkspacesilent, 7"
          "$mod SHIFT, 8  , movetoworkspacesilent, 8"
          "$mod SHIFT, 9  , movetoworkspacesilent, 9"
          "$mod SHIFT, 0  , movetoworkspacesilent, 10"
          "$mod SHIFT, F1 , movetoworkspacesilent, 11"
          "$mod SHIFT, F2 , movetoworkspacesilent, 12"
          "$mod SHIFT, F3 , movetoworkspacesilent, 13"
          "$mod SHIFT, F4 , movetoworkspacesilent, 14"
          "$mod SHIFT, F5 , movetoworkspacesilent, 15"
          "$mod SHIFT, F6 , movetoworkspacesilent, 16"
          "$mod SHIFT, F7 , movetoworkspacesilent, 17"
          "$mod SHIFT, F8 , movetoworkspacesilent, 18"
          "$mod SHIFT, F9 , movetoworkspacesilent, 19"
          "$mod SHIFT, F10, movetoworkspacesilent, 20"
          "$mod SHIFT, F11, movetoworkspacesilent, 21"
          "$mod SHIFT, F12, movetoworkspacesilent, 22"

          # Workspace navigation (bracket keys like XMonad)
          "$mod, bracketleft, focusmonitor, -1"
          "$mod, bracketright, focusmonitor, +1"
          #"$mod SHIFT, bracketleft, movewindow, mon:+1"
          #"$mod SHIFT, bracketright, movewindow, mon:-1"
          "$mod SHIFT, bracketleft, movecurrentworkspacetomonitor,+1"
          "$mod SHIFT, bracketright, movecurrentworkspacetomonitor, -1"

          # Scratchpads (using special workspaces to mimic your scratchpads)
          "$mod, n, exec, scratchPad sp"
          "$mod, m, exec, scratchPad ghci"
          "$mod, v, exec, scratchPad vim"
          "$mod, c, exec, scratchPad calcurse"
          "$mod, b, exec, scratchPad vit"
          "$mod, t, exec, onScratchPad --hide-after vit quickadd quick-add-task"
          "$mod, p, exec, onScratchPad --hide-after vit process process"

          # System controls
          "$mod SHIFT, s, exec, suspend-with-dpms-fix"
          "$mod SHIFT, r, exec, onScratchPad --hide-after sp rebuild rebuild"

          # Screenshots
          ", Print, exec, sh -c 'wayfreeze & sleep 0.1; SELECTION=$(slurp); grim -g \"$SELECTION\" - | (sleep 0.1;pkill wayfreeze; swappy -f -)'"
          "$mod, Print, exec, grim ~/Pictures/screenshot-$(date +'%Y%m%d-%H%M%S').png"

          # Bluetooth
          "$mod SHIFT, b, exec, bluetooth-autoconnect"
        ];

        # Mouse bindings
        bindm = [
          "$mod, mouse:272, movewindow"
          "$mod, mouse:273, resizewindow"
        ];

        # Media keys
        bindle = [
          ", XF86AudioRaiseVolume, exec, pulsemixer --change-volume +1"
          ", XF86AudioLowerVolume, exec, pulsemixer --change-volume -1"
        ];
        bindl = [
          ", XF86AudioMute, exec, pulsemixer --toggle-mute"
          ", XF86AudioPlay, exec, playPause"
          ", XF86AudioNext, exec, playerctl next"
          ", XF86AudioPrev, exec, playerctl previous"
          "$mod SHIFT, p, exec, playPause"
          "$mod, o, exec, playerctl next -a"
        ];

        # Startup applications (matching your XMonad startup)
        exec-once = [
          # waybar, hypridle, and hyprpaper are started by systemd via their respective service enables
          "mako"
          # Launch all Firefox profiles directly to their workspaces
          "[workspace 1 silent]  firefox -P youtube --new-instance"
          "[workspace 2 silent]  firefox -P default"
          "[workspace 18 silent] firefox -P work --new-instance"
          "[workspace 20 silent] firefox -P ttrpg --new-instance"
          "[workspace 21 silent] (hypr-await; discord)"
          "[workspace 21 silent] (hypr-await --group 21; signal-desktop)"
          # Auto-connect to Bluetooth headphones
          "bluetooth-autoconnect"
          # Pester me about any swap files
          "check-swaps"
          # Set Blue Snowball as default mic (state is wiped on reboot)
          "sleep 2 && pactl set-default-source alsa_input.usb-BLUE_MICROPHONE_Blue_Snowball_SUGA_2020_11_28_42691-00.mono-fallback"
        ];
      };
    };
  };
}
