{ config, pkgs, lib, ... }:

{
  # Enable Tailscale VPN
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    # These are only applied by the tailscale-reset thing.
    extraUpFlags = [
      "--ssh"
      "--accept-routes"
      "--accept-dns"
      "--operator=${config.mainUser}"
      "--advertise-exit-node"
    ];
  };

  # Reset Tailscale preferences on boot to match NixOS config
  # This ensures manual `tailscale set` commands don't persist unexpectedly
  # Uses `tailscale up --reset` to enforce complete desired state
  systemd.services.tailscale-reset-prefs = {
    description = "Reset Tailscale preferences to NixOS defaults";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Wait for tailscaled to be ready
      sleep 2
      ${pkgs.tailscale}/bin/tailscale up --reset ${lib.concatStringsSep " " config.services.tailscale.extraUpFlags}
    '';
  };

  # Enable the required kernel module for NAT traversal
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Open firewall ports for Tailscale
  networking.firewall = {
    # Allow Tailscale traffic
    allowedUDPPorts = [ 41641 ];
    # Trust the Tailscale interface
    trustedInterfaces = [ "tailscale0" ];
  };

  # Ensure tailscale package is available in system
  environment.systemPackages = with pkgs; [
    tailscale
  ];

  # Auto-start tailscale daemon on boot
  systemd.services.tailscaled = {
    wantedBy = [ "multi-user.target" ];
  };
}
