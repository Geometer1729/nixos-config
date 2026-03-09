{ flake, lib, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{

  networking.hostName = "am";
  networking.interfaces.enp4s0.wakeOnLan.enable = true;
  amd = true;
  drive = "/dev/nvme0n1";
  system.stateVersion = "25.05";

  # Cross-compilation support via QEMU binfmt emulation
  nix.settings.extra-platforms = [ "i686-linux" "aarch64-linux" ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Monitor setup for desktop
  home-manager.users.bbrian = {
    # Disable hypridle completely on this machine to test if it's causing display flickering
    services.hypridle.enable = lib.mkForce false;

    programs.hyprland-custom = {
      dualMonitor = true;
      primaryMonitor = "HDMI-A-1,2560x1440@60,0x0,1";
      secondaryMonitor = "DP-1,1920x1080@60,2560x0,1";
    };
  };

  imports = [
    ./hardware.nix
  ] ++ (with self.nixosModules; [
    default
    builder
    taskchampion
    foundryvtt
  ]);
}
