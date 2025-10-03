{ pkgs, lib, ... }:
let
  settings =
    {
      layer = "top";
      position = "top";
      height = 24;
      output = [ "HDMI-A-1" ]; # Primary monitor

      modules-left = [ "hyprland/workspaces" "hyprland/window" ];
      modules-center = [ ];
      modules-right = [ "pulseaudio#source" "pulseaudio" "network" "cpu" "temperature" "memory" "clock" ];

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
      "pulseaudio#source" = {
        format = "{format_source}";
        format-source = "{volume}%";
        format-source-muted = "🔇{volume}%";
        format-icons = {
          headphone = "";
          hands-free = "";
          headset = "";
          phone = "";
          portable = "";
          car = "";
          default = [ "" "" ];
        };
        on-click = "pactl set-source-mute @DEFAULT_SOURCE@ toggle";
        on-click-right = "pavucontrol -t 4";
        on-scroll-up = "pactl set-source-volume @DEFAULT_SOURCE@ +5%";
        on-scroll-down = "pactl set-source-volume @DEFAULT_SOURCE@ -5%";
        tooltip = false;
      };
      pulseaudio = {
        format = "{volume}%";
        format-bluetooth = "{volume}%";
        format-muted = "🔇{volume}%";
        format-source = "source?";
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
        on-click-right = "pavucontrol -t 3";
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

      temperature = {
        hwmon-path = "/sys/class/hwmon/hwmon1/temp1_input"; # k10temp CPU sensor
        format = "{icon} {temperatureC}°C ";
        critical-threshold = 85;
        #format-icons = [ "" "" "" ];
      };

      # CPU usage
      cpu = {
        format = "{usage}% ";
        tooltip = false;
        on-click = "hyprctl dispatch exec ${pkgs.alacritty}/bin/alacritty -e ${pkgs.btop}/bin/btop";
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
    };
in
{
  home.packages = with pkgs; [
    pulseaudioFull
    pavucontrol
  ];
  stylix.targets.waybar = {
    enable = true;
    addCss = true;
    enableLeftBackColors = true;
    enableRightBackColors = true;
  };
  programs.waybar = {
    enable = true;
    settings = [ settings (settings // { output = [ "DP-1" ]; }) ];

    # Styling similar to your XMobar colors
  };
}
