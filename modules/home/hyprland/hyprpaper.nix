{ pkgs, config, lib, ... }:
let
  wallpapersDir = "${config.home.homeDirectory}/Pictures/Wallpapers";
  defaultWallpaper = "${wallpapersDir}/purpleSpace.jpg";
  rotateWallpaper = pkgs.writeShellScript "rotate-wallpaper" ''
    set -eu

    wallpapers_dir=${lib.escapeShellArg wallpapersDir}
    state_dir=${lib.escapeShellArg "${config.xdg.stateHome}/wallpaper-rotation"}
    index_file="$state_dir/index"
    if [ ! -d "$wallpapers_dir" ]; then
      exit 0
    fi

    mkdir -p "$state_dir"

    mapfile -d $'\0' wallpapers < <(
      ${pkgs.findutils}/bin/find "$wallpapers_dir" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \) \
        -print0 | ${pkgs.coreutils}/bin/sort -z
    )

    if [ "''${#wallpapers[@]}" -eq 0 ]; then
      exit 0
    fi

    count="''${#wallpapers[@]}"
    next_index=0
    if [ -f "$index_file" ]; then
      last_index=$(${pkgs.coreutils}/bin/cat "$index_file")
      if [[ "$last_index" =~ ^[0-9]+$ ]]; then
        next_index=$(( (last_index + 1) % count ))
      fi
    fi

    wallpaper="''${wallpapers[$next_index]}"

    if ! ${pkgs.hyprland}/bin/hyprctl -j monitors >/dev/null 2>&1; then
      exit 0
    fi

    while IFS= read -r monitor; do
      [ -n "$monitor" ] || continue
      ${pkgs.hyprland}/bin/hyprctl hyprpaper wallpaper "$monitor,$wallpaper"
    done < <(${pkgs.hyprland}/bin/hyprctl -j monitors | ${pkgs.jq}/bin/jq -r '.[].name')

    printf '%s\n' "$next_index" > "$index_file"
  '';
in
{
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      splash_offset = 2;

      # You can set wallpapers here - adjust paths as needed
      preload = [
        defaultWallpaper
      ];

      wallpaper = [
        "HDMI-A-1,${defaultWallpaper}"
        "DP-1,${defaultWallpaper}"
      ];
    };
  };

  # Override the systemd service to explicitly pass the config file
  systemd.user.services.hyprpaper = {
    Service = {
      ExecStart = pkgs.lib.mkForce "${pkgs.hyprpaper}/bin/hyprpaper --config ${config.xdg.configHome}/hypr/hyprpaper.conf";
    };
  };

  systemd.user.services.rotate-wallpaper = {
    Unit = {
      Description = "Rotate Hyprpaper wallpaper";
      After = [ "hyprpaper.service" "graphical-session.target" ];
      Wants = [ "hyprpaper.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = rotateWallpaper;
    };
  };

  systemd.user.timers.rotate-wallpaper = {
    Unit = {
      Description = "Rotate wallpaper every hour";
    };
    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1h";
      Persistent = true;
      Unit = "rotate-wallpaper.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
