{ pkgs, lib, config, osConfig, ... }:
let
  cfg = config.programs.hyprland-custom;
  scratchpads = import ./scratchpads.nix;
  scratchpadPattern = lib.concatMapStringsSep "|" (scratchpad: scratchpad.name) scratchpads;

  toLua = lib.generators.toLua { multiline = false; };
  lua = lib.generators.mkLuaInline;
  exec = command: lua "hl.dsp.exec_cmd(${toLua command})";
  dsp = name: args: lua "hl.dsp.${name}(${toLua args})";

  mod = "ALT"; # Using Alt like your XMonad setup
  # Renders a call to the config's bind function, which also records the action
  # under its description for Rofi's Keybinds mode.
  bindWith = opts: keys: description: action:
    "bind(${toLua keys}, ${toLua action}, ${toLua (opts // { inherit description; })})";
  bind = bindWith { };

  monitorName = line: builtins.head (lib.splitString "," line);
  monitorSpec = line:
    let fields = lib.splitString "," line;
    in {
      output = builtins.elemAt fields 0;
      mode = builtins.elemAt fields 1;
      position = builtins.elemAt fields 2;
      scale = builtins.elemAt fields 3;
    };
  # Workspace n is on key n, 0 for 10, then F1-F12 for 11-22 like your XMonad.
  workspaceKeys = map toString (lib.range 1 9) ++ [ "0" ] ++ map (i: "F${toString i}") (lib.range 1 12);
in
{
  options.programs.hyprland-custom = {
    dualMonitor = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to use dual monitor setup";
    };

    primaryMonitor = lib.mkOption {
      type = lib.types.str;
      description = "Primary monitor as output,mode,position,scale";
    };

    secondaryMonitor = lib.mkOption {
      type = lib.types.str;
      description = "Secondary monitor as output,mode,position,scale (only used if dualMonitor is true)";
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
      # NixOS manages both portal backends; Home Manager would hide KDE's backend.
      portalPackage = null;
      configType = "lua";
      plugins = [
        #REEE I can't get plugins to build
      ];
      # Each attribute becomes an hl.<name>(...) call; see the Hyprland Lua stubs.
      settings = {
        monitor = map monitorSpec ([ cfg.primaryMonitor ] ++ lib.optional cfg.dualMonitor cfg.secondaryMonitor);

        config = {
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
              # Floating windows show the wallpaper, not the windows behind them,
              # like urxvt's fake transparency.
              xray = true;
            };
          };

          animations.enabled = true;

          # Layout configuration
          dwindle = {
            preserve_split = true;
          };

          # Misc settings - most managed by Stylix
          misc = {
            force_default_wallpaper = -1;
            # Clicked notifications (Slack, Signal, Discord) ask to be focused this way.
            focus_on_activate = true;
            # Lets a restarted hyprlock take over the lock after it crashes.
            allow_session_lock_restore = true;
            #enable_swallow = true;
            #swallow_regex = ".*prismlauncher.*";
          };

          group = {
            auto_group = true;
            group_on_movetoworkspace = true;
          };
        };

        curve = { _args = [ "myBezier" { type = "bezier"; points = [ [ 0.05 0.9 ] [ 0.1 1.05 ] ]; } ]; };
        animation = map (animation: { enabled = true; } // animation) [
          { leaf = "windows"; speed = 7; bezier = "myBezier"; }
          { leaf = "windowsOut"; speed = 7; bezier = "default"; style = "popin 80%"; }
          { leaf = "border"; speed = 10; bezier = "default"; }
          { leaf = "borderangle"; speed = 8; bezier = "default"; }
          { leaf = "fade"; speed = 7; bezier = "default"; }
          { leaf = "workspaces"; speed = 6; bezier = "default"; }
        ];

        # Workspaces - 22 workspaces total
        workspace_rule =
          let
            onMonitor = line: map (i: { workspace = toString i; monitor = monitorName line; });
          in
          if cfg.dualMonitor then
          # Dual monitor: split workspaces between monitors
            onMonitor cfg.primaryMonitor ((lib.range 1 5) ++ (lib.range 11 15))
            ++ onMonitor cfg.secondaryMonitor ((lib.range 6 10) ++ (lib.range 16 22))
          else
          # Single monitor: all workspaces on primary
            onMonitor cfg.primaryMonitor (lib.range 1 22);

        window_rule = [
          # Force prismlauncher to tile to prevent floating positioning issues with swallow
          { match.class = "prismlauncher"; tile = true; }
          # Maximize messaging apps on workspace 21 (xmonad Full layout style)
          { match.class = "(discord|signal|slack)"; fullscreen_state = "1 0"; }
          # Page fullscreen requests (YouTube f) only tell Brave it is fullscreen.
          { match.class = "brave-origin"; sync_fullscreen = false; }

          { match.class = ".blueman-manager-wrapped"; float = true; size = "monitor_w*0.5 monitor_h*0.5"; center = true; }
          { match.title = "^Wi-Fi picker$"; float = true; size = "monitor_w*0.6 monitor_h*0.65"; center = true; }
          { match.title = "float"; float = true; }
          { match.class = "discord"; workspace = "21 silent"; }
          { match.class = "signal"; workspace = "21 silent"; }
          { match.class = "Slack"; workspace = "21 silent"; }
          { match.title = "Steam"; workspace = "10 silent"; }
          { match.title = "^(${scratchpadPattern})$"; float = true; size = "monitor_w*0.5 monitor_h*0.5"; center = true; }
        ] ++ map
          (workspace: { match.title = "^Brave WS ${toString workspace}$"; workspace = "${toString workspace} silent"; })
          (lib.range 1 22);

        on = {
          _args = [
            "hyprland.start"
            (lua ''
              function()
                -- waybar, hypridle, and hyprpaper are started by systemd via their respective service enables
                hl.exec_cmd("mako")
                hl.exec_cmd("blueman-applet")
                -- Brave restores the previously named windows; the listener places them.
                hl.exec_cmd("brave-restore-session", { workspace = "2 silent" })
                hl.exec_cmd("env NIXOS_SPEECH=False discord", { workspace = "21 silent" })
                hl.exec_cmd("signal-desktop", { workspace = "21 silent" })
                -- Auto-connect to Bluetooth headphones
                hl.exec_cmd("bluetooth-autoconnect")
                -- Pester me about any swap files
                hl.exec_cmd("check-swaps")
              end'')
          ];
        };
      };

      # Keybindings - translating your XMonad bindings
      extraConfig = ''
        -- hyprctl binds only lists Lua binds as references, so record each
        -- action for Rofi's Keybinds mode to run by its description.
        keybind_actions = {}
        local function bind(keys, action, opts)
          hl.bind(keys, action, opts)
          keybind_actions[opts.description] = action
        end

        ${lib.concatStringsSep "\n" ([
          # Application launchers
          (bind "${mod} + Return" "Open terminal" (exec "ghostty"))
          (bind "${mod} + d" "Open command palette" (exec "rofi -show combi"))
          (bind "${mod} + SHIFT + d" "Open password picker" (exec "passmenu"))
          (bind "${mod} + s" "Open SSH launcher" (exec "rofi -show ssh"))
          (bind "${mod} + r" "Run a command" (exec "rofi -show run"))
          (bind "${mod} + slash" "Show key help for the focused app" (exec "key-help"))
          (bind "${mod} + SHIFT + slash" "Search Hyprland keybinds" (exec "rofi -show keybinds"))
          (bind "${mod} + SHIFT + n" "Start a ticket" (exec "start-ticket"))
          (bind "${mod} + SHIFT + Return" "Open Brave window for this workspace" (exec "brave-workspace-window"))
          (bind "${mod} + u" "Clean URL in clipboard" (exec "clean-url"))
          (bind "${mod} + SHIFT + v" "Open clipboard history" (exec "clipboard-history"))
          (bind "${mod} + CTRL + v" "Force paste clipboard by typing it" (exec "force-paste"))
          (bind "${mod} + e" "Hold to dictate" (exec "dictate start"))
          (bind "${mod} + SHIFT + e" "Hold to dictate a new task" (exec "dictate start task"))
          # Release half of push-to-talk dictation. The script delivers the text
          # to where the press was, so focus can move on before it arrives.
          # Transparent: when Alt comes up before E, Hyprland 0.57 shadows binds
          # matching the still-held E, which would swallow this release.
          (bindWith { release = true; transparent = true; } "${mod} + e" "Stop dictation and deliver text" (exec "dictate stop"))
          (bindWith { release = true; transparent = true; } "${mod} + SHIFT + e" "Stop dictation and deliver text" (exec "dictate stop"))

          # Notifications
          (bind "${mod} + i" "Open notification history" (exec "notification-center history"))
          (bind "${mod} + SHIFT + i" "Click top notification" (exec "notification-center click"))
          (bind "${mod} + x" "Dismiss all notifications" (exec "makoctl dismiss -a"))
          (bind "${mod} + SHIFT + x" "Restore last dismissed notification" (exec "makoctl restore"))
          (bind "${mod} + z" "Toggle Do Not Disturb" (exec "notification-center dnd"))
          (bind "${mod} + SHIFT + z" "Mute work sessions until morning" (exec "notification-center work"))

          # Window management
          (bind "${mod} + q" "Close active window" (lua "hl.dsp.window.close()"))
          (bind "${mod} + SHIFT + q" "Exit Hyprland" (lua "hl.dsp.exit()"))
          (bind "${mod} + space" "Toggle floating window" (lua "hl.dsp.window.float()"))
          (bind "${mod} + w" "Toggle maximized window" (dsp "window.fullscreen" { mode = "maximized"; }))
          # TODO this works pretty badly tbh and I really wish it was automatic
          # fullscreen_state pins sync_fullscreen on the window; unset it so window rules apply again.
          (bind "${mod} + f" "Tell application it is fullscreen" (lua ''
            function()
              local window = hl.get_active_window()
              if not window then return end
              hl.dispatch(hl.dsp.window.fullscreen_state({ internal = window.fullscreen, client = 2 }))
              hl.dispatch(hl.dsp.window.set_prop({ prop = "sync_fullscreen", value = "unset" }))
            end''))

          # Cycle to next window and maximize (xmonad Full layout style)
          (bind "${mod} + Tab" "Cycle to next window and maximize" (lua ''
            function()
              hl.dispatch(hl.dsp.window.cycle_next())
              hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized" }))
            end''))

          # Focus movement (vim-style like your XMonad)
          (bind "${mod} + h" "Focus window to the left" (dsp "focus" { direction = "left"; }))
          (bind "${mod} + l" "Focus window to the right" (dsp "focus" { direction = "right"; }))
          (bind "${mod} + k" "Focus window above" (dsp "focus" { direction = "up"; }))
          (bind "${mod} + j" "Focus window below" (dsp "focus" { direction = "down"; }))

          # Window movement
          (bind "${mod} + SHIFT + h" "Move window left" (dsp "window.move" { direction = "left"; }))
          (bind "${mod} + SHIFT + l" "Move window right" (dsp "window.move" { direction = "right"; }))
          (bind "${mod} + SHIFT + k" "Move window up" (dsp "window.move" { direction = "up"; }))
          (bind "${mod} + SHIFT + j" "Move window down" (dsp "window.move" { direction = "down"; }))
        ]
        # Workspace switching and moving windows to workspaces
        ++ lib.imap1 (i: key: bind "${mod} + ${key}" "Switch to workspace ${toString i}" (dsp "focus" { workspace = i; })) workspaceKeys
        ++ lib.imap1
          (i: key: bind "${mod} + SHIFT + ${key}" "Move window to workspace ${toString i} silently"
            (dsp "window.move" { workspace = i; follow = false; }))
          workspaceKeys
        ++ [
          # Workspace navigation (bracket keys like XMonad)
          (bind "${mod} + bracketleft" "Focus previous monitor" (dsp "focus" { monitor = "-1"; }))
          (bind "${mod} + bracketright" "Focus next monitor" (dsp "focus" { monitor = "+1"; }))
          (bind "${mod} + SHIFT + bracketleft" "Move workspace to next monitor" (dsp "workspace.move" { monitor = "+1"; }))
          (bind "${mod} + SHIFT + bracketright" "Move workspace to previous monitor" (dsp "workspace.move" { monitor = "-1"; }))
        ]
        # Scratchpads (using special workspaces)
        ++ map
          (scratchpad: bind "${mod} + ${scratchpad.key}" "Toggle ${scratchpad.name} scratchpad" (exec "scratchPad ${scratchpad.name}"))
          scratchpads
        ++ [
          (bind "${mod} + t" "Quick-add a task" (exec "onScratchPad --hide-after vit quickadd quick-add-task"))
          (bind "${mod} + SHIFT + t" "Write a quick note" (exec "onScratchPad --hide-after vim quicknote quick-note"))
          (bind "${mod} + p" "Process tasks" (exec "onScratchPad --hide-after vit process process"))

          # System controls
          (bind "${mod} + SHIFT + s" "Suspend computer" (exec "suspend-with-dpms-fix"))
          (bind "${mod} + SHIFT + r" "Rebuild NixOS" (exec "onScratchPad --hide-after sp rebuild rebuild"))
          (bind "${mod} + SHIFT + w" "Change wallpaper" (exec "systemctl --user start rotate-wallpaper.service"))
          (bind "${mod} + SHIFT + m" "Toggle mono audio output" (exec "toggle-mono-output"))
          (bind "${mod} + SHIFT + a" "Toggle manual keep-awake (locking stays enabled)" (exec "keep-awake toggle"))

          # Screenshots
          (bind "Print" "Screenshot selected region and annotate" (exec "sh -c 'wayfreeze & sleep 0.1; SELECTION=$(slurp); grim -g \"$SELECTION\" - | (sleep 0.1;pkill wayfreeze; swappy -f -)'"))
          (bind "SHIFT + Print" "OCR selected region to clipboard" (exec "ocr-region"))
          (bind "${mod} + Print" "Save full screenshot to Pictures" (exec "grim ~/Pictures/screenshot-$(date +'%Y%m%d-%H%M%S').png"))

          # Bluetooth
          (bind "${mod} + SHIFT + b" "Connect Bluetooth headphones" (exec "bluetooth-autoconnect"))

          # Mouse bindings
          (bindWith { mouse = true; } "${mod} + mouse:272" "Drag to move window" (lua "hl.dsp.window.drag()"))
          (bindWith { mouse = true; } "${mod} + mouse:273" "Drag to resize window" (lua "hl.dsp.window.resize()"))

          # Media keys
          (bindWith { locked = true; repeating = true; } "XF86AudioRaiseVolume" "Raise volume" (exec "pulsemixer --change-volume +1"))
          (bindWith { locked = true; repeating = true; } "XF86AudioLowerVolume" "Lower volume" (exec "pulsemixer --change-volume -1"))
          (bindWith { locked = true; } "XF86AudioMute" "Toggle mute" (exec "pulsemixer --toggle-mute"))
          (bindWith { locked = true; } "XF86AudioPlay" "Play or pause media" (exec "playPause"))
          (bindWith { locked = true; } "XF86AudioNext" "Next media track" (exec "playerctl next"))
          (bindWith { locked = true; } "XF86AudioPrev" "Previous media track" (exec "playerctl previous"))
          (bindWith { locked = true; } "${mod} + SHIFT + p" "Play or pause media" (exec "playPause"))
          (bindWith { locked = true; } "${mod} + o" "Next track on all players" (exec "playerctl next -a"))
        ])}
      '';
    };

    # Parse the generated config with the Hyprland the session launches, so
    # option renames/removals in updates fail the build before activation.
    home.checks = [
      (pkgs.runCommand "hyprland-config-check" { nativeBuildInputs = [ osConfig.programs.hyprland.package ]; } ''
        export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR/run
        mkdir -p "$XDG_RUNTIME_DIR"
        Hyprland --verify-config -c ${config.xdg.configFile."hypr/hyprland.lua".source}
        touch $out
      '')
    ];
  };
}
