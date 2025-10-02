{ pkgs, lib, config, osConfig, ... }:
{
  # Install Hyprland-related packages
  home.packages = with pkgs; [
    hyprpaper # wallpaper daemon
    hypridle # idle daemon
    hyprlock # screen locker
    hyprpicker # color picker
    wl-clipboard # clipboard utilities
    grim # screenshot utility
    slurp # area selection for screenshots
    waybar # status bar
    walker # launcher (what Omarchy uses)
    xdg-desktop-portal-hyprland
  ];

  # Hyprland configuration
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # Monitor configuration - matching your XMonad setup
      monitor = [
        "HDMI-A-1,2560x1440@60,0x0,1" # Primary monitor
        "DP-1,1920x1080@60,2560x0,1" # Secondary monitor to the right
      ];

      # Input configuration
      input = {
        kb_layout = osConfig.services.xserver.xkb.layout or "us";
        kb_options = osConfig.services.xserver.xkb.options or "";

        follow_mouse = 1;
        sensitivity = 0; # -1.0 - 1.0, 0 means no modification
      };

      # General settings
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 1;

        # Colors managed by Stylix

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
      };

      # Workspaces - matching your XMonad 22 workspaces
      workspace =
        # Create workspaces 1-10 on primary monitor
        (map (i: "${toString i}, monitor:HDMI-A-1") (lib.range 1 10)) ++
        # Create workspaces 11-22 on secondary monitor
        (map (i: "${toString i}, monitor:DP-1") (lib.range 11 22));

      # Window rules
      windowrule = [
        #"float, ^(blueman-manager)$"
        "float, title:^(float)$"
        #"workspace 21, ^(discord)$"
        #"workspace 21, ^(Discord)$"
        #"workspace 10, ^(Steam)$"
      ];

      # Keybindings - translating your XMonad bindings
      "$mod" = "ALT"; # Using Alt like your XMonad setup

      bind = [
        # Application launchers
        "$mod, Return, exec, alacritty"
        "$mod, d, exec, wofi --show drun"
        "$mod, s, exec, wofi --show run"

        # Window management
        "$mod, q, killactive"
        "$mod SHIFT, q, exit"
        "$mod, space, togglefloating"
        "$mod, f, fullscreen"

        # Layout cycling (approximating your layout bindings)
        "$mod, w, exec, hyprctl keyword general:layout dwindle"
        "$mod, g, exec, hyprctl keyword general:layout master"
        "$mod SHIFT, w, cyclenext"

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
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"
        "$mod SHIFT, F1, movetoworkspace, 11"
        "$mod SHIFT, F2, movetoworkspace, 12"
        "$mod SHIFT, F3, movetoworkspace, 13"
        "$mod SHIFT, F4, movetoworkspace, 14"
        "$mod SHIFT, F5, movetoworkspace, 15"
        "$mod SHIFT, F6, movetoworkspace, 16"
        "$mod SHIFT, F7, movetoworkspace, 17"
        "$mod SHIFT, F8, movetoworkspace, 18"
        "$mod SHIFT, F9, movetoworkspace, 19"
        "$mod SHIFT, F10, movetoworkspace, 20"
        "$mod SHIFT, F11, movetoworkspace, 21"
        "$mod SHIFT, F12, movetoworkspace, 22"

        # Workspace navigation (bracket keys like XMonad)
        "$mod, bracketleft, workspace, -1"
        "$mod, bracketright, workspace, +1"
        "$mod SHIFT, bracketleft, movetoworkspace, -1"
        "$mod SHIFT, bracketright, movetoworkspace, +1"

        # Tab navigation
        "$mod, Tab, workspace, previous"
        "$mod SHIFT, Tab, cyclenext, prev"

        # Scratchpads (using special workspaces to mimic your scratchpads)
        "$mod, n, togglespecialworkspace, sp"
        "$mod, m, togglespecialworkspace, ghci"
        "$mod, v, togglespecialworkspace, vim"
        "$mod, c, togglespecialworkspace, calcurse"
        "$mod, b, togglespecialworkspace, vit"

        # Move to scratchpads
        "$mod SHIFT, n, movetoworkspace, special:sp"
        "$mod SHIFT, m, movetoworkspace, special:ghci"
        "$mod SHIFT, v, movetoworkspace, special:vim"
        "$mod SHIFT, c, movetoworkspace, special:calcurse"
        "$mod SHIFT, b, movetoworkspace, special:vit"

        # System controls
        "$mod SHIFT, r, exec, systemctl --user restart hyprland.service" # Rebuild equivalent
        "$mod SHIFT, s, exec, sudo systemctl suspend"

        # Screenshots
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
        "$mod, Print, exec, grim ~/Pictures/screenshot-$(date +'%Y%m%d-%H%M%S').png"

        # Bluetooth
        "$mod SHIFT, b, exec, echo 'connect 60:AB:D2:42:5E:19' | bluetoothctl"
      ];

      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Media keys
      bindl = [
        ", XF86AudioRaiseVolume, exec, pulsemixer --change-volume +1"
        ", XF86AudioLowerVolume, exec, pulsemixer --change-volume -1"
        ", XF86AudioMute, exec, pulsemixer --toggle-mute"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
        "$mod SHIFT, p, exec, playerctl play-pause"
        "$mod, o, exec, playerctl next -a"
      ];

      # Startup applications (matching your XMonad startup)
      exec-once = [
        "waybar"
        "hyprpaper"
        "hypridle"
        "sleep 10 && firefox"
        "discord"
        "echo 'connect 60:AB:D2:42:5E:19' | bluetoothctl"
        # Create scratchpad terminals
        "[workspace special:sp silent] alacritty -t sp -e tmux new-session -A -s sp"
        "[workspace special:ghci silent] alacritty -t ghci -e tmux new-session -A -s ghci ghci"
        "[workspace special:vim silent] alacritty -t vim -e tmux new-session -A -s vim vim"
        "[workspace special:calcurse silent] alacritty -t calcurse -e tmux new-session -A -s calcurse calcurse"
        "[workspace special:vit silent] alacritty -t vit -e tmux new-session -A -s vit vit"
      ];
    };
  };
}
