{ pkgs, flake, config, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{

  networking.hostName = "torag";
  drive = "/dev/nvme0n1";

  # NixOS-level wifi configuration
  wifi = {
    enable = true;
    interface = "wlp0s20f3";
  };

  home-manager.users.${config.mainUser} = {
    fast_lock = true;
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
