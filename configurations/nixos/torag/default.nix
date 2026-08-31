{ flake, config, pkgs, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  wakeupAm = pkgs.writeShellScriptBin "wakeup-am" ''
    exec ${pkgs.openssh}/bin/ssh balrog wakeonlan 24:4b:fe:57:0b:55
  '';
  sshAmProxy = pkgs.writeShellScript "ssh-am-proxy" ''
    ${wakeupAm}/bin/wakeup-am >&2

    for _ in {1..60}; do
      if ${pkgs.netcat-openbsd}/bin/nc -z -w 1 "$1" "$2"; then
        exec ${pkgs.netcat-openbsd}/bin/nc "$1" "$2"
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done

    echo "Timed out waiting for $1:$2 after waking am" >&2
    exit 1
  '';
in
{

  networking.hostName = "torag";
  machine.hasGui = true;
  drive = "/dev/nvme0n1";

  # NixOS-level wifi configuration
  wifi = {
    enable = true;
    interface = "wlp0s20f3";
  };

  home-manager.users.${config.mainUser} = {
    fast_lock = true;
    home.packages = [ wakeupAm ];
    programs.ssh.matchBlocks.am.proxyCommand = "${sshAmProxy} %h %p";
    #programs.alacritty.settings.font.size = pkgs.lib.mkForce 9;

    # Single monitor setup for laptop
    programs.hyprland-custom = {
      dualMonitor = false;
      primaryMonitor = "eDP-1,1920x1080@60,0x0,1";
      battery = true;
    };
  };

  imports =
    with self.nixosModules;
    [
      ./hardware.nix
      default
      useBuilders
    ];
}
