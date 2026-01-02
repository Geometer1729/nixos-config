{ lib, ... }:
{
  programs.fuse.userAllowOther = true;
  environment.persistence."/persist/system" = {
    hideMounts = true;
    directories = [
      "/var/log"
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
        ".config/icloud-sync/credentials"
        ".gnupg"
        ".hoogle"
        ".local/share/PrismLauncher"
        ".local/share/Steam"
        ".local/share/direnv"
        ".local/share/task"
        ".local/share/wasistlos"
        ".local/state/nvim"
        ".claude" # Claude Code state and configuration
        ".mozilla/firefox/default"
        ".mozilla/firefox/youtube"
        ".mozilla/firefox/work"
        ".mozilla/firefox/ttrpg"
        ".cache/mozilla/firefox" # maybe this is needed to not lose tabs sometimes?
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
        ".zsh_history" # This seems to not work, and causes some sort of permissions error
        ".config/lazygit/state.yml"
        ".cache/nix-index/files"
        ".cache/rofi3.druncache"
        ".cache/rofi-2.sshcache"
        ".cache/rofi-entry-history.txt"
        ".local/share/nix/trusted-settings.json" # stop having to retrust flakes
        ".local/share/nix/repl-history" # nix repl command history
        ".git-credentials"
        ".config/gh/hosts.yml"
        ".config/tailscale/ssh_known_hosts"
        #".config/task/taskrc" # persisted just for news.version :(
        ".claude.json"
        ".claude/.credentials.json"
      ];
    };
  };

  fileSystems."/persist".neededForBoot = true;
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir /btrfs_tmp
    mount /dev/root_vg/root /btrfs_tmp
    if [[ -e /btrfs_tmp/root ]]; then
        mkdir -p /btrfs_tmp/old_roots
        timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
        mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
    fi

    delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "/btrfs_tmp/$i"
        done
        btrfs subvolume delete "$1"
    }

    for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
        delete_subvolume_recursively "$i"
    done

    btrfs subvolume create /btrfs_tmp/root
    umount /btrfs_tmp
  '';
}
