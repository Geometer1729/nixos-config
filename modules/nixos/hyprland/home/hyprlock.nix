{ config, lib, ... }:
{
  programs.hyprlock = {
    enable = true;
    settings.general.ignore_empty_input = true;
  };

  # Start only on a lock request, in a cgroup independent of hypridle.
  systemd.user.services.hyprlock = {
    Unit = {
      Description = "Hyprland session lock";
      ConditionEnvironment = "WAYLAND_DISPLAY";
      After = [ config.wayland.systemd.target ];
      PartOf = [ config.wayland.systemd.target ];
      # An active locker must survive package/config changes until unlock.
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "exec";
      ExecStart = lib.getExe config.programs.hyprlock.package;
    };
  };
}
