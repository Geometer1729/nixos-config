{ config, lib, machine, pkgs, ... }:
let
  cfg = config.services.workload-inhibit;
in
{
  options.services.workload-inhibit = {
    enable = lib.mkEnableOption "automatic sleep inhibition for active workloads";
  };

  config = {
    services.workload-inhibit.enable = lib.mkDefault machine.hasGui;

    scripts.keep-awake = {
      directory = ./.;
      runtimeEnv = {
        KEEP_AWAKE_BUILD_GROUP = config.nix.settings.build-users-group or "nixbld";
        KEEP_AWAKE_AUTOMATIC = lib.boolToString cfg.enable;
      };
    };

    systemd.services.workload-inhibit = lib.mkIf cfg.enable {
      description = "Keep active Nix workloads awake";
      wantedBy = [ "multi-user.target" ];
      wants = [ "systemd-logind.service" ];
      after = [ "systemd-logind.service" ];
      partOf = [ "systemd-logind.service" ];
      serviceConfig = {
        ExecStart = "${lib.getExe config.scripts.keep-awake.packages.keep-awake} monitor";
        Restart = "on-failure";
        RestartSec = 2;
        # Stopping or restarting the unit kills its systemd-inhibit children,
        # so a crash never leaves a stale hold.
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
      };
    };

    # No WantedBy: the manual override starts only on a click/shortcut, and
    # graphical-session shutdown clears it even when the user manager lingers.
    systemd.user.services.keep-awake-manual = lib.mkIf machine.hasGui {
      description = "Manual keep-awake (automatic locking remains enabled)";
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "exec";
        ExecStart = lib.escapeShellArgs [
          "${pkgs.systemd}/bin/systemd-inhibit"
          "--what=sleep"
          "--mode=block"
          "--who=keep-awake-manual"
          "--why=Manual hold until toggled off or logout"
          "${pkgs.coreutils}/bin/sleep"
          "infinity"
        ];
      };
    };
  };
}
