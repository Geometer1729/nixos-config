{ config, pkgs, lib, ... }:

{
  # Enable Tailscale VPN
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
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
