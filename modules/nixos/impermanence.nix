{ ... }:
{
  programs.fuse.userAllowOther = true;
  environment.persistence."/persist/system" = {
    hideMounts = true;
    directories = [
      "/var/log"
      {
        directory = "/var/cache/tuigreet";
        user = "greeter";
        group = "greeter";
        mode = "0755";
      }
      "/var/lib/bluetooth"
      "/var/lib/tailscale"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/hass"
      "/etc/nixos/" # currently manually symlinked to "~/conf" ideally the config would do that
      "/root/.ssh"
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
        ".config/Signal"
        ".config/discord"
        ".config/spotify"
        ".config/Slack"
        ".config/clorio-wallet"
        ".config/ncspot"
        ".config/chromium"
        ".config/google-chrome"
        ".config/meridian"
        ".gnupg"
        ".hoogle"
        ".local/share/PrismLauncher"
        ".local/share/Steam"
        ".local/share/Anki2"
        ".local/share/direnv"
        ".local/share/opencode"
        ".local/share/task"
        ".local/share/git"
        ".local/state/mighty-rearranger"
        ".local/state/nvim"
        # Claude Code: persist entire directories to avoid file-level bind mount issues
        ".claude-work"
        ".claude-personal"
        ".config/opencode"
        ".mozilla/firefox/default"
        ".mozilla/firefox/youtube"
        ".mozilla/firefox/work"
        ".mozilla/firefox/ttrpg"
        ".cache/mozilla/firefox" # maybe this is needed to not lose tabs sometimes?
        ".cache/meridian"
        ".ssh"
        ".tldrc"
        "Code"
        "Documents"
        "Pictures"
        "conf"
        "memes"
        "password-store"
      ];
      files = [
        # zsh_history: NOT bind-mounted here — zsh writes directly to /persist via history.path
        # Bind-mounting a single file breaks zsh's write-new-then-rename strategy
        ".config/lazygit/state.yml"
        ".cache/nix-index/files"
        ".cache/rofi3.druncache"
        ".cache/rofi-2.sshcache"
        ".cache/rofi-entry-history.txt"
        ".local/share/nix/trusted-settings.json" # stop having to retrust flakes
        ".local/share/nix/repl-history" # nix repl command history
        ".config/gh/hosts.yml"
        ".config/tailscale/ssh_known_hosts"
        # Syncthing device identity only — config.xml is regenerated declaratively
        ".local/state/syncthing/cert.pem"
        ".local/state/syncthing/key.pem"
        #".config/task/taskrc" # persisted just for news.version :(
      ];
    };
    users.yixin = {
      directories = [
        "."
      ];
    };
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
