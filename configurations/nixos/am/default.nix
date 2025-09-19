{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{

  networking.hostName = "am";
  amd = true;
  drive = "/dev/nvme0n1";
  cloudflare-id = "3981fa82-1e49-4e4c-8df9-962a244d988a";
  system.stateVersion = "22.05";

  # Machine-specific Nix configuration for cross-compilation
  # TODO verify this works
  nix.settings.extra-platforms = [ "i686-linux" "aarch64-linux" ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  services.xserver.displayManager.sessionCommands = ''
    xrandr --output HDMI-1 --mode 2560x1440 --rate 60 --primary
    xrandr --output DP-2 --mode 1920x1080 --rate 60 --right-of HDMI-1
    # reset Wallpapers after xrandr commands
    feh --randomize --bg-fill ~/Pictures/Wallpapers/
  '';

  imports = with self.nixosModules;
    [
      ./hardware.nix
      default

      builder
    ];
}
