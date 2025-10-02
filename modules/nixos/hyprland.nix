{ config, pkgs, ... }:
{
  services.getty.autologinUser = config.mainUser;

  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # XDG portal for Hyprland
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  services = {
    # Display manager for Wayland
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };
      sessionPackages = [ pkgs.hyprland ];
      autoLogin = {
        enable = true;
        user = config.mainUser;
      };
      defaultSession = "hyprland";
    };

    # Keep your keyboard configuration
    xserver = {
      xkb.options = "caps:swapescape";
      xkb.layout = "us";
    };
  };

  console.useXkbConfig = true;

  # Environment variables for Hyprland
  environment.sessionVariables = {
    # If your cursor becomes invisible
    WLR_NO_HARDWARE_CURSORS = "1";
    # Hint electron apps to use wayland
    NIXOS_OZONE_WL = "1";
  };
}
