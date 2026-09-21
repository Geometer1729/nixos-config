{ config, lib, pkgs, ... }:
let
  cfg = config.storageHealth;
  user = config.mainUser;
  host = config.networking.hostName;

  # Read the message from stdin so disk-provided text never becomes SSH shell code.
  notify = pkgs.writeShellApplication {
    name = "storage-health-notify";
    runtimeInputs = with pkgs; [ coreutils libnotify ];
    text = ''
      XDG_RUNTIME_DIR="/run/user/$(id -u)"
      export XDG_RUNTIME_DIR
      export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
      message=$(cat)
      notify-send --app-name=storage-health --urgency=critical --expire-time=0 \
        -- "Storage health: $1" "$message"
    '';
  };

  smartdNotify = pkgs.writeShellApplication {
    name = "smartd-notify";
    runtimeInputs = with pkgs; [ coreutils openssh systemd util-linux ];
    text = ''
      printf '%s\n' "$SMARTD_FULLMESSAGE" | systemd-cat --identifier=storage-health --priority=warning
      ${if cfg.notificationHost == null then ''
        printf '%s\n\n%s\n' "$SMARTD_DEVICESTRING" "$SMARTD_MESSAGE" | timeout 30s \
          runuser -u ${lib.escapeShellArg user} -- ${notify}/bin/storage-health-notify ${lib.escapeShellArg host}
      '' else ''
        printf '%s\n\n%s\n' "$SMARTD_DEVICESTRING" "$SMARTD_MESSAGE" | timeout 30s \
          runuser -u ${lib.escapeShellArg user} -- \
          ssh -T -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
          ${lib.escapeShellArg "${user}@${cfg.notificationHost}"} \
          ${lib.escapeShellArg (lib.escapeShellArgs [ "/run/current-system/sw/bin/storage-health-notify" host ])}
      ''}
    '';
  };
in
{
  options.storageHealth.notificationHost = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "am";
    description = "Desktop to receive SMART alerts over SSH as mainUser; null delivers locally.";
  };

  config = {
    assertions = [{
      assertion = config.machine.hasGui || cfg.notificationHost != null;
      message = "Headless storage-health hosts need storageHealth.notificationHost.";
    }];

    services.btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
      # /, /nix and /persist are subvolumes of the same filesystem.
      fileSystems = [ "/" ];
    };

    services.smartd = {
      enable = true;
      autodetect = true;
      # Keep state explicitly: smartmontools' default state saving is build-dependent.
      extraOptions = [ "--savestates=/var/lib/smartmontools/" ];
      defaults.monitored = "-a -m <nomailer> -M daily -M exec ${smartdNotify}/bin/smartd-notify";
      # DEVICESCAN inherits DEFAULT; avoid repeating notification directives.
      defaults.autodetected = "";
      notifications = {
        mail.enable = false;
        wall.enable = false;
        x11.enable = false;
      };
    };

    environment.systemPackages = [ pkgs.smartmontools ] ++ lib.optional config.machine.hasGui notify;
    systemd.services.smartd.serviceConfig.StateDirectory = "smartmontools";
    systemd.services.btrfs-scrub--.serviceConfig.StateDirectory = "btrfs";

    environment.persistence."/persist/system" = {
      directories = [
        "/var/lib/smartmontools"
        "/var/lib/btrfs"
        # systemd updates timer stamps without following symlinks; persist the
        # directory so first-boot impermanence file symlinks cannot lose them.
        "/var/lib/systemd/timers"
      ];
    };
  };
}
