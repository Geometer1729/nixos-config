{ pkgs, lib, ... }:
let
  settings =
    {
      layer = "top";
      position = "top";
      height = 24;
      output = [ "HDMI-A-1" ]; # Primary monitor

      modules-left = [ "hyprland/workspaces" "hyprland/window" ];
      modules-center = [ "clock" ];
      modules-right = [
        "pulseaudio#source"
        "pulseaudio"
        "network"
        "temperature"
        "cpu"
        "memory"
      ];

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
        on-click = "hyprctl dispatch exec 'alacritty -e btop'";
        #format-icons = [ "" "" "" ];
      };

      # CPU usage
      cpu = {
        format = "{usage}% ";
        tooltip = false;
        on-click = "hyprctl dispatch exec 'alacritty -e btop'";
      };

      # Memory usage
      memory = {
        format = "{}% ";
        on-click = "hyprctl dispatch exec 'alacritty -e btop'";
      };

      # Clock
      clock = {
        timezone = "America/New_York";
        tooltip-format = "{:%a %d}\n<tt><small>{calendar}</small></tt>";
        calendar.format.today = "<b>{}</b>";
        # TODO calandly on-click would be cool
        format = "{:%m-%d-%Y : %a : %H:%M:%S}";
        format-alt = "{:%a %H:%M:%S}";
        interval = 1;
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
    enableCenterBackColors = false;
    enableRightBackColors = true;
  };

  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      target = "hyprland-session.target";
    };
    settings = {
      mainBar = settings;
      secondaryBar = settings // { output = [ "DP-1" ]; };
    };
    # Override workspace colors to match hyprland window borders
    # I don't like the stylix defaults here
    style = ''
      window#waybar #workspaces button {
        background-color: @base07;
        color: @base00;
      }

      window#waybar #workspaces button.active {
        background-color: @base0D;
        color: @base00;
      }
    '';
  };


}
