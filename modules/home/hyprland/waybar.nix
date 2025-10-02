{ pkgs, lib, ... }:
{
  programs.waybar = {
    enable = true;
    settings = [
      # Primary monitor bar
      {
        layer = "top";
        position = "top";
        height = 24;
        output = [ "HDMI-A-1" ]; # Primary monitor

        modules-left = [ "hyprland/workspaces" "hyprland/window" ];
        modules-center = [ ];
        modules-right = [ "pulseaudio" "network" "cpu" "memory" "clock" ];

        # Workspaces module - similar to your XMonad workspace display
        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = false;
          format = "{name}";
          format-icons = {
            urgent = "";
            active = "";
            default = "";
          };
          on-click = "activate";
        };

        # Window title - similar to your XMobar title display
        "hyprland/window" = {
          format = "{title}";
          max-length = 40;
          separate-outputs = true;
        };

        # Audio
        pulseaudio = {
          format = "{volume}% {icon}";
          format-bluetooth = "{volume}% {icon}";
          format-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" ];
          };
          on-click = "pulsemixer --toggle-mute";
          on-click-right = "pavucontrol";
          on-scroll-up = "pulsemixer --change-volume +1";
          on-scroll-down = "pulsemixer --change-volume -1";
        };

        # Network
        network = {
          format-wifi = "{essid} ({signalStrength}%) ";
          format-ethernet = "{ifname} ";
          format-disconnected = "Disconnected ";
          max-length = 50;
        };

        # CPU usage
        cpu = {
          format = "{usage}% ";
          tooltip = false;
        };

        # Memory usage
        memory = {
          format = "{}% ";
        };

        # Clock
        clock = {
          timezone = "America/New_York";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          format-alt = "{:%Y-%m-%d}";
        };
      }

      # Secondary monitor bar
      {
        layer = "top";
        position = "top";
        height = 24;
        output = [ "DP-1" ]; # Secondary monitor

        modules-left = [ "hyprland/workspaces" "hyprland/window" ];
        modules-center = [ ];
        modules-right = [ "pulseaudio" "network" "cpu" "memory" "clock" ];

        # Workspaces module - similar to your XMonad workspace display
        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = false;
          format = "{name}";
          format-icons = {
            urgent = "";
            active = "";
            default = "";
          };
          on-click = "activate";
        };

        # Window title - similar to your XMobar title display
        "hyprland/window" = {
          format = "{title}";
          max-length = 40;
          separate-outputs = true;
        };

        # Audio
        pulseaudio = {
          format = "{volume}% {icon}";
          format-bluetooth = "{volume}% {icon}";
          format-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" ];
          };
          on-click = "pulsemixer --toggle-mute";
          on-click-right = "pavucontrol";
          on-scroll-up = "pulsemixer --change-volume +1";
          on-scroll-down = "pulsemixer --change-volume -1";
        };

        # Network
        network = {
          format-wifi = "{essid} ({signalStrength}%) ";
          format-ethernet = "{ifname} ";
          format-disconnected = "Disconnected ";
          max-length = 50;
        };

        # CPU usage
        cpu = {
          format = "{usage}% ";
          tooltip = false;
        };

        # Memory usage
        memory = {
          format = "{}% ";
        };

        # Clock
        clock = {
          timezone = "America/New_York";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          format-alt = "{:%Y-%m-%d}";
        };
      }
    ];

    # Styling similar to your XMobar colors
    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "Hack Nerd Font";
        font-size: 12px;
        min-height: 0;
      }

      window#waybar {
        background: rgba(43, 48, 59, 0.9);
        border-bottom: 1px solid rgba(100, 114, 125, 0.5);
        color: #ffffff;
      }

      /* Workspaces styling - mimicking XMobar workspace indicators */
      #workspaces {
        margin: 0 4px;
      }

      #workspaces button {
        padding: 0 5px;
        background: transparent;
        color: #ffffff;
        border-bottom: 2px solid transparent;
      }

      #workspaces button:hover {
        background: rgba(0, 0, 0, 0.2);
      }

      #workspaces button.active {
        background: #64727D;
        border-bottom: 2px solid #ffffff;
      }

      #workspaces button.urgent {
        background-color: #eb4d4b;
      }

      /* Window title styling */
      #window {
        margin: 0 4px;
        padding: 0 4px;
        color: #6ab04c;  /* Green color like your XMobar title */
      }

      /* Right modules styling */
      #pulseaudio, #network, #cpu, #memory, #clock {
        padding: 0 8px;
        margin: 0 2px;
      }

      #pulseaudio {
        color: #f39c12;
      }

      #network {
        color: #3498db;
      }

      #cpu {
        color: #e74c3c;
      }

      #memory {
        color: #9b59b6;
      }

      #clock {
        color: #f1c40f;  /* Yellow color like your XMobar */
        font-weight: bold;
      }
    '';
  };
}
