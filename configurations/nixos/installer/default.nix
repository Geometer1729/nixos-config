{ modulesPath, pkgs, ... }:
let
  keys = import ../../../ssh-authorized-keys.nix;
  disk-report = pkgs.writeShellApplication {
    name = "disk-report";
    runtimeInputs = with pkgs; [ coreutils findutils gnugrep hdparm smartmontools systemd util-linux ];
    text = ''
      if [[ $# -ne 1 ]]; then
        echo "usage: disk-report /dev/sdX" >&2
        exit 2
      fi

      disk=$(readlink -f -- "$1")
      if [[ ! -b "$disk" ]]; then
        echo "$1 does not resolve to a block device" >&2
        exit 1
      fi
      if [[ $(lsblk -dnro TYPE "$disk") != disk ]]; then
        echo "$disk is not a whole disk" >&2
        exit 1
      fi

      echo "=== CANONICAL DEVICE ==="
      printf '%s -> %s\n' "$1" "$disk"
      echo
      echo "=== ALL DISKS ==="
      lsblk -d -e 7 -o NAME,PATH,SIZE,MODEL,SERIAL,WWN,TRAN,ROTA,TYPE
      echo
      echo "=== PARTITIONS AND MOUNTS ==="
      lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS "$disk"
      echo
      echo "=== UDEV IDENTITY ==="
      udevadm info --query=property --name="$disk" | grep -E '^(DEVNAME|ID_BUS|ID_MODEL|ID_PATH|ID_SERIAL|ID_SERIAL_SHORT|ID_WWN)=' || true
      echo
      echo "=== STABLE BY-ID NAMES ==="
      find -L /dev/disk/by-id -maxdepth 1 -samefile "$disk" -print | sort
      echo
      echo "=== SMART IDENTITY ==="
      smartctl -i "$disk" || true
      echo
      echo "No installation has been performed. Record the model, serial, capacity,"
      echo "WWN, and a non-partition /dev/disk/by-id path before continuing."
    '';
  };
in
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  networking.hostName = "nixos-installer";
  nixpkgs.hostPlatform = "x86_64-linux";

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };
  users.users.root.openssh.authorizedKeys.keys = keys;

  environment.systemPackages = [ disk-report ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "26.05";
}
