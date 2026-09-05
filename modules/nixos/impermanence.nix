{ config, lib, ... }:
{
  programs.fuse.userAllowOther = true;
  environment.persistence."/persist/system" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/tailscale"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/nixos/"
      "/root/.ssh"
    ] ++ lib.optionals config.machine.hasGui [
      {
        directory = "/var/cache/tuigreet";
        user = "greeter";
        group = "greeter";
        mode = "0755";
      }
      "/var/lib/bluetooth"
      "/var/lib/hass"
    ];
    files = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
      "/etc/machine-id"
      "/root/.config/tailscale/ssh_known_hosts"
    ];
    users.bbrian = {
      directories = [
        ".gnupg"
        ".local/share/direnv"
        ".local/share/opencode"
        ".local/share/nvim/site"
        ".local/share/nvim/auto_session"
        ".local/share/nvim/sessions"
        ".local/share/nvim/spell"
        ".local/share/task"
        ".local/share/git"
        ".local/state/nvim"
        ".local/state/opencode"
        ".local/state/tmux"
        ".tmux/resurrect"
        ".claude-work"
        ".claude-personal"
        ".config/meridian"
        ".config/opencode"
        ".ssh"
        ".tldrc"
        "Code"
        "Documents"
        "Pictures"
        "conf"
        "memes"
        "password-store"
      ] ++ lib.optionals config.machine.hasGui [
        ".config/Signal"
        ".config/discord"
        ".config/spotify"
        ".config/Slack"
        ".config/clorio-wallet"
        ".config/ncspot"
        ".config/chromium"
        ".config/google-chrome"
        ".config/BraveSoftware/Brave-Origin"
        ".hoogle"
        ".local/share/PrismLauncher"
        ".local/share/Steam"
        ".local/share/Anki2"
        ".mozilla/firefox/default"
        ".mozilla/firefox/youtube"
        ".mozilla/firefox/work"
        ".mozilla/firefox/ttrpg"
        ".cache/mozilla/firefox"
        ".cache/meridian"
      ];
      files = [
        # zsh_history is written directly to /persist so rename-based updates work.
        ".config/lazygit/state.yml"
        ".cache/nix-index/files"
        ".local/share/nix/trusted-settings.json"
        ".local/share/nix/repl-history"
        ".local/share/nvim/telescope_history"
        ".config/gh/hosts.yml"
        ".config/tailscale/ssh_known_hosts"
        ".local/state/syncthing/cert.pem"
        ".local/state/syncthing/key.pem"
      ] ++ lib.optionals config.machine.hasGui [
        ".cache/rofi3.druncache"
        ".cache/rofi-2.sshcache"
        ".cache/rofi-entry-history.txt"
      ];
    };
    users.yixin.directories = lib.mkIf config.machine.hasGui [ "." ];
  };

  fileSystems."/persist".neededForBoot = true;
  boot.initrd.systemd.services.rollback-root = {
    description = "Rotate btrfs root subvolume";
    wantedBy = [ "initrd.target" ];
    requires = [ "initrd-root-device.target" ];
    after = [
      "initrd-root-device.target"
      "local-fs-pre.target"
    ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    script = ''
      set -euo pipefail

      mkdir -p /btrfs_tmp
      mount -t btrfs -o subvol=/ /dev/root_vg/root /btrfs_tmp

      delete_subvolume_recursively() {
          IFS=$'\n'
          for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
              delete_subvolume_recursively "/btrfs_tmp/$i"
          done
          btrfs subvolume delete "$1"
      }

      if [[ -d /btrfs_tmp/old_roots ]]; then
          for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
              delete_subvolume_recursively "$i"
          done
      fi

      if [[ -e /btrfs_tmp/root ]]; then
          mkdir -p /btrfs_tmp/old_roots
          timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%d_%H:%M:%S")
          mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
      fi

      btrfs subvolume create /btrfs_tmp/root
      umount /btrfs_tmp
    '';
  };
}
