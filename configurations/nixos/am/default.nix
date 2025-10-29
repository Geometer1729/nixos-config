{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{

  networking.hostName = "am";
  amd = true;
  drive = "/dev/nvme0n1";
  system.stateVersion = "25.05";

  # Machine-specific Nix configuration for cross-compilation
  # TODO verify this works
  nix.settings.extra-platforms = [ "i686-linux" "aarch64-linux" ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Monitor setup for desktop
  home-manager.users.bbrian = {
    #icloud-tasks = true;
    programs.hyprland-custom = {
      dualMonitor = true;
      primaryMonitor = "HDMI-A-1,2560x1440@60,0x0,1";
      secondaryMonitor = "DP-1,1920x1080@60,2560x0,1";
    };
  };

  imports = with self.nixosModules;
    [
      ./hardware.nix
      default

      builder
    ];
}
