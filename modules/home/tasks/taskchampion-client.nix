{ config, lib, pkgs, osConfig, ... }:
let
  # Use the same client_id across all machines to share the same task list
  # Each user should have their own unique client_id
  clientId = "a3c4f6e8-1234-5678-9abc-def012345678";
in
{
  programs.taskwarrior = {
    config = {
      # Taskchampion sync configuration
      sync = {
        server = {
          url = "http://am:8888";
          client_id = clientId;
        };
        # Encryption secret is set via activation script from sops
      };
    };
  };

  # Set sync secret from sops
  home.activation.setTaskwarriorSyncSecret = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -f /run/secrets/taskwarrior-sync-secret ]; then
      SECRET=$(cat /run/secrets/taskwarrior-sync-secret)
      $DRY_RUN_CMD ${pkgs.taskwarrior3}/bin/task rc.confirmation=off config sync.encryption_secret "$SECRET"
    fi
  '';

  # Add sync alias
  programs.zsh.shellAliases = {
    ts = "task sync";
  };

  # Automatic sync service
  systemd.user.services.taskwarrior-sync = {
    Unit = {
      Description = "Taskwarrior sync service";
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.taskwarrior3}/bin/task sync";
      # Don't fail if sync has issues (e.g., server unavailable)
      SuccessExitStatus = [ 0 1 ];
    };
  };

  # Automatic sync timer - runs every 5 minutes
  systemd.user.timers.taskwarrior-sync = {
    Unit = {
      Description = "Taskwarrior sync timer";
    };
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
