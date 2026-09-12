{ flake, config, lib, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{

  nixos-unified.sshTarget = "${config.mainUser}@${config.networking.hostName}";
  system.stateVersion = "25.05";

  # Remove 90 second wait from rebuild ffs
  virtualisation.virtualbox.guest.enable = false;
  services.tcsd.enable = false;

  nixpkgs.overlays = lib.mkBefore [
    # PrismLauncher nightly overlay (new auth system)
    inputs.prismlauncher.overlays.default
  ];
  home-manager.users = {
    root.imports = [ (self + /configurations/users/root.nix) ];
  };

  nix.sshServe.keys = import ../../ssh-authorized-keys.nix;

  services.tailscale = {
    useRoutingFeatures = "server";
    extraUpFlags = lib.mkAfter [ "--advertise-exit-node" ];
  };

  imports =
    with self.nixosModules;
    [
      #inputs
      inputs.nur.modules.nixos.default
      (self + /configurations/users/yixin)
      #self
      base
      brave
      bt
      docker
      gh-noto
      hyprland
      kde
      main
      steam
      work
      wifi
      #xlibre #honestly I think nixpkgs is breaking this on purpose :(
      yubikey
      hm-fallback
    ];
}
